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
    expect(svc.buildNewMessageAnnouncement('  '), '你有一条来自未知联系人的新消息');
  });

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
