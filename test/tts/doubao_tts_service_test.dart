import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talk/tts/doubao_tts_config_store.dart';
import 'package:talk/tts/doubao_tts_models.dart';
import 'package:talk/tts/doubao_tts_service.dart';

void main() {
  test('build new message announcement uses sender name', () {
    final svc = DoubaoTtsService(
      store: _MemoryStore(),
      httpClient: _FakeChunkedClient((_) => const []),
      customAudioPlayer: (_) async {},
    );
    expect(svc.buildNewMessageAnnouncement('张三'), '你有一条来自张三的新消息');
    expect(
      svc.buildNewMessageAnnouncement('张三', summary: '今日任务有5条，重点是喂猫。'),
      '张三 发来消息：今日任务有5条，重点是喂猫。',
    );
    expect(svc.buildNewMessageAnnouncement('  '), '你有一条来自未知联系人的新消息');
  });

  test(
    'summarizeMessageForAnnouncement calls qwen compatible endpoint',
    () async {
      http.BaseRequest? sentRequest;
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: _FakeResponseClient((request) {
          sentRequest = request;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '今日任务有5条，重点是喂猫和买方便面。'},
                  },
                ],
              }),
            ),
            200,
          );
        }),
        customAudioPlayer: (_) async {},
      );

      final summary = await svc.summarizeMessageForAnnouncement(
        senderName: 'todo',
        roomName: '日程todo',
        messageBody: '1. 喂猫\n2. 买方便面\n3. 倒垃圾\n4. 洗衣服\n5. 交电费',
        config: const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'tts-key',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
          announceMessageContent: true,
          qwenApiKey: 'qwen-key',
          qwenModel: 'qwen3.6-flash',
          qwenSystemPrompt: '整理消息',
        ),
      );

      expect(summary, '今日任务有5条，重点是喂猫和买方便面。');
      expect(
        sentRequest!.url.toString(),
        contains('/compatible-mode/v1/chat/completions'),
      );
      expect(sentRequest!.headers['Authorization'], 'Bearer qwen-key');
      final body =
          jsonDecode((sentRequest! as http.Request).body)
              as Map<String, dynamic>;
      expect(body['model'], 'qwen3.6-flash');
      expect(jsonEncode(body['messages']), contains('日程todo'));
      expect(jsonEncode(body['messages']), contains('喂猫'));
    },
  );

  test(
    'summarizeMessageForAnnouncement removes duplicated notification prefix',
    () async {
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: _FakeResponseClient((request) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': 'todo 发来新消息：今日任务有5条，重点是喂猫。'},
                  },
                ],
              }),
            ),
            200,
          );
        }),
        customAudioPlayer: (_) async {},
      );

      final summary = await svc.summarizeMessageForAnnouncement(
        senderName: 'todo',
        roomName: '日程todo',
        messageBody: '1. 喂猫\n2. 买方便面\n3. 倒垃圾\n4. 洗衣服\n5. 交电费',
        config: const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'tts-key',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
          announceMessageContent: true,
          qwenApiKey: 'qwen-key',
        ),
      );

      expect(summary, '今日任务有5条，重点是喂猫。');
    },
  );

  test('enqueueNewMessageAnnouncement summarizes content before tts', () async {
    final requests = <http.BaseRequest>[];
    Uint8List? played;
    final raw = base64Encode(Uint8List.fromList(const [9, 9, 9]));
    final svc = DoubaoTtsService(
      store: _MemoryStore(),
      httpClient: _FakeResponseClient((request) {
        requests.add(request);
        if (request.url.toString().contains('dashscope')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '今日任务有5条，重点是喂猫。'},
                  },
                ],
              }),
            ),
            200,
          );
        }
        return http.Response(
          '{"code":0,"message":"","data":"$raw"}'
          '{"code":20000000,"message":"ok","data":null}',
          200,
        );
      }),
      customAudioPlayer: (bytes) async {
        played = Uint8List.fromList(bytes);
      },
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        apiKey: 'tts-key',
        resourceId: 'seed-tts-2.0',
        speaker: 'spk',
        announceMessageContent: true,
        qwenApiKey: 'qwen-key',
      ),
    );

    await svc.enqueueNewMessageAnnouncement(
      senderName: 'todo',
      roomName: '日程todo',
      messageBody: '1. 喂猫\n2. 买方便面\n3. 倒垃圾\n4. 洗衣服\n5. 交电费',
    );

    expect(requests.length, 2);
    final ttsBody =
        jsonDecode((requests.last as http.Request).body)
            as Map<String, dynamic>;
    expect(
      (ttsBody['req_params'] as Map<String, dynamic>)['text'],
      'todo 发来消息：今日任务有5条，重点是喂猫。',
    );
    expect(played, orderedEquals(const [9, 9, 9]));
  });

  test(
    'enqueueNewMessageAnnouncement uses realtime dialog content engine',
    () async {
      final realtimeCalls = <String>[];
      var ttsRequests = 0;
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: _FakeChunkedClient((_) {
          ttsRequests += 1;
          return const <String>[];
        }),
        customAudioPlayer: (_) async {},
        realtimeAnnouncementPlayer: (config, text) async {
          expect(config.realtimeAppId, 'app-id');
          realtimeCalls.add(text);
        },
      );
      await svc.saveConfig(
        const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'tts-key',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
          announceMessageContent: true,
          contentEngine: VoiceAnnouncementContentEngine.realtimeDialog,
          realtimeAppId: 'app-id',
          realtimeAppKey: 'app-key',
          realtimeAccessToken: 'token',
          realtimeSummaryPrompt: '请用一句话提醒我这条消息',
        ),
      );

      await svc.enqueueNewMessageAnnouncement(
        senderName: 'todo',
        roomName: '日程todo',
        messageBody: '今天任务有5条：喂猫、买方便面、倒垃圾、洗衣服、交电费。',
      );

      expect(realtimeCalls, hasLength(1));
      expect(realtimeCalls.single, contains('请用一句话提醒我这条消息'));
      expect(realtimeCalls.single, isNot(contains('只说摘要内容')));
      expect(realtimeCalls.single, contains('日程todo'));
      expect(realtimeCalls.single, contains('喂猫'));
      expect(ttsRequests, 0);
    },
  );

  test(
    'enqueueNewMessageAnnouncement falls back to qwen tts when realtime fails',
    () async {
      final requests = <http.BaseRequest>[];
      final raw = base64Encode(Uint8List.fromList(const [8, 8]));
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: _FakeResponseClient((request) {
          requests.add(request);
          if (request.url.toString().contains('dashscope')) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'choices': [
                    {
                      'message': {'content': '今日任务有5条，重点是喂猫。'},
                    },
                  ],
                }),
              ),
              200,
            );
          }
          return http.Response(
            '{"code":0,"message":"","data":"$raw"}'
            '{"code":20000000,"message":"ok","data":null}',
            200,
          );
        }),
        customAudioPlayer: (_) async {},
        realtimeAnnouncementPlayer: (_, _) async {
          throw StateError('realtime unavailable');
        },
      );
      await svc.saveConfig(
        const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'tts-key',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
          announceMessageContent: true,
          contentEngine: VoiceAnnouncementContentEngine.realtimeDialog,
          qwenApiKey: 'qwen-key',
          realtimeAppId: 'app-id',
          realtimeAppKey: 'app-key',
          realtimeAccessToken: 'token',
        ),
      );

      await svc.enqueueNewMessageAnnouncement(
        senderName: 'todo',
        roomName: '日程todo',
        messageBody: '今天任务有5条：喂猫、买方便面、倒垃圾、洗衣服、交电费。',
      );

      expect(requests.length, 2);
      final ttsBody =
          jsonDecode((requests.last as http.Request).body)
              as Map<String, dynamic>;
      expect(
        (ttsBody['req_params'] as Map<String, dynamic>)['text'],
        'todo 发来消息：今日任务有5条，重点是喂猫。',
      );
    },
  );

  test('speakNow decodes chunked json audio and plays bytes', () async {
    final store = _MemoryStore();
    final raw = base64Encode(Uint8List.fromList(const [1, 2, 3]));
    http.BaseRequest? sentRequest;
    final client = _FakeChunkedClient((request) {
      sentRequest = request;
      return [
        '{"code":0,"message":"","data":"$raw"}',
        '{"code":20000000,"message":"ok","data":null}',
      ];
    });
    Uint8List? played;
    final svc = DoubaoTtsService(
      store: store,
      httpClient: client,
      customAudioPlayer: (bytes) async {
        played = Uint8List.fromList(bytes);
      },
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        apiKey: 'k',
        resourceId: 'seed-tts-2.0',
        speaker: 'spk',
      ),
    );

    await svc.speakNow('测试');
    expect(played, isNotNull);
    expect(played!, orderedEquals(const [1, 2, 3]));
    expect(sentRequest!.headers['X-Api-Key'], 'k');
    expect(sentRequest!.headers['X-Api-Resource-Id'], 'seed-tts-2.0');
  });

  test('speakNow supports legacy app token auth headers', () async {
    http.BaseRequest? sentRequest;
    final raw = base64Encode(Uint8List.fromList(const [4, 5, 6]));
    final client = _FakeChunkedClient((request) {
      sentRequest = request;
      return [
        '{"code":0,"message":"","data":"$raw"}',
        '{"code":20000000,"message":"ok","data":null}',
      ];
    });
    final svc = DoubaoTtsService(
      store: _MemoryStore(),
      httpClient: client,
      customAudioPlayer: (_) async {},
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        authMode: DoubaoTtsAuthMode.appToken,
        apiKey: '',
        appId: 'app-1',
        accessKey: 'token-1',
        resourceId: 'seed-tts-2.0',
        speaker: 'spk',
      ),
    );

    await svc.speakNow('测试');

    expect(sentRequest!.headers['X-Api-App-Id'], 'app-1');
    expect(sentRequest!.headers['X-Api-Access-Key'], 'token-1');
    expect(sentRequest!.headers.containsKey('X-Api-Key'), isFalse);
  });

  test('speakNow sends configured synthesis parameters', () async {
    http.BaseRequest? sentRequest;
    final raw = base64Encode(Uint8List.fromList(const [7, 8, 9]));
    final client = _FakeChunkedClient((request) {
      sentRequest = request;
      return [
        '{"code":0,"message":"","data":"$raw"}',
        '{"code":20000000,"message":"ok","data":null}',
      ];
    });
    final svc = DoubaoTtsService(
      store: _MemoryStore(),
      httpClient: client,
      customAudioPlayer: (_) async {},
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        apiKey: 'k',
        resourceId: 'seed-tts-2.0',
        speaker: 'spk',
        speechRate: 20,
        loudnessRate: -10,
        markdownFilterEnabled: true,
        latexEnabled: true,
        filterParentheses: false,
        explicitDialect: 'dongbei',
        pitch: -2,
        contextTexts: ['你可以说慢一点吗？'],
      ),
    );

    await svc.speakNow('测试');

    final body =
        jsonDecode((sentRequest! as http.Request).body) as Map<String, dynamic>;
    final reqParams = body['req_params'] as Map<String, dynamic>;
    final audioParams = reqParams['audio_params'] as Map<String, dynamic>;
    final additions =
        jsonDecode(reqParams['additions'] as String) as Map<String, dynamic>;
    expect(audioParams['speech_rate'], 20);
    expect(audioParams['loudness_rate'], -10);
    expect(additions['disable_markdown_filter'], isTrue);
    expect(additions['enable_latex_tn'], isTrue);
    expect(additions['latex_parser'], 'v2');
    expect(additions['max_length_to_filter_parenthesis'], 0);
    expect(additions['explicit_dialect'], 'dongbei');
    expect(additions['post_process'], {'pitch': -2});
    expect(additions['context_texts'], ['你可以说慢一点吗？']);
  });

  test(
    'speakNow omits default additions to keep baseline request compatible',
    () async {
      http.BaseRequest? sentRequest;
      final raw = base64Encode(Uint8List.fromList(const [7, 8, 9]));
      final client = _FakeChunkedClient((request) {
        sentRequest = request;
        return [
          '{"code":0,"message":"","data":"$raw"}',
          '{"code":20000000,"message":"ok","data":null}',
        ];
      });
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: client,
        customAudioPlayer: (_) async {},
      );
      await svc.saveConfig(
        const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'k',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
        ),
      );

      await svc.speakNow('测试');

      final body =
          jsonDecode((sentRequest! as http.Request).body)
              as Map<String, dynamic>;
      final reqParams = body['req_params'] as Map<String, dynamic>;
      expect(reqParams.containsKey('additions'), isFalse);
    },
  );

  test(
    'speakNow reports non-audio stream event when synthesis returns no data',
    () async {
      final client = _FakeChunkedClient((_) {
        return const [
          '{"code":45000001,"message":"bad additions","data":null}',
          '{"code":20000000,"message":"ok","data":null}',
        ];
      });
      final svc = DoubaoTtsService(
        store: _MemoryStore(),
        httpClient: client,
        customAudioPlayer: (_) async {},
      );
      await svc.saveConfig(
        const DoubaoTtsConfig(
          enabled: true,
          apiKey: 'k',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
        ),
      );

      expect(
        () => svc.speakNow('测试'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bad additions'),
          ),
        ),
      );
    },
  );

  test('enqueueNewMessageAnnouncement skips when disabled', () async {
    final store = _MemoryStore();
    var requests = 0;
    final client = _FakeChunkedClient((_) {
      requests += 1;
      return const <String>[];
    });
    final svc = DoubaoTtsService(
      store: store,
      httpClient: client,
      customAudioPlayer: (_) async {},
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: false,
        apiKey: 'k',
        resourceId: 'seed-tts-2.0',
        speaker: 'spk',
      ),
    );
    await svc.enqueueNewMessageAnnouncement(senderName: '李四');
    expect(requests, 0);
  });

  test(
    'enabling voice announcement disables realtime secretary first',
    () async {
      var disableSecretaryCalls = 0;
      final store = _MemoryStore();
      final svc = DoubaoTtsService(
        store: store,
        httpClient: _FakeChunkedClient((_) => const []),
        customAudioPlayer: (_) async {},
        disableRealtimeSecretary: () async => disableSecretaryCalls += 1,
      );
      await svc.saveConfig(
        const DoubaoTtsConfig(
          enabled: false,
          apiKey: 'k',
          resourceId: 'seed-tts-2.0',
          speaker: 'spk',
        ),
      );

      await svc.setEnabled(true);

      expect(disableSecretaryCalls, 1);
      expect(store.config!.enabled, isTrue);
    },
  );
}

class _MemoryStore implements DoubaoTtsConfigStore {
  DoubaoTtsConfig? config;

  @override
  Future<void> clear() async {
    config = null;
  }

  @override
  Future<DoubaoTtsConfig?> load() async {
    return config;
  }

  @override
  Future<void> save(DoubaoTtsConfig cfg) async {
    config = cfg;
  }
}

class _FakeChunkedClient extends http.BaseClient {
  _FakeChunkedClient(this._chunksBuilder);

  final List<String> Function(http.BaseRequest request) _chunksBuilder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final chunks = _chunksBuilder(request);
    final stream = Stream<List<int>>.fromIterable(
      chunks.map((s) => utf8.encode(s)),
    );
    return http.StreamedResponse(
      stream,
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _FakeResponseClient extends http.BaseClient {
  _FakeResponseClient(this._handler);

  final http.Response Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
