import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talk/quick_extract/deepseek_config.dart';
import 'package:talk/quick_extract/deepseek_config_store.dart';
import 'package:talk/quick_extract/deepseek_quick_extract_service.dart';

void main() {
  test('deepseek quick extract parses json candidates', () async {
    http.BaseRequest? sentRequest;
    final service = DeepSeekQuickExtractService(
      store: _MemoryStore(),
      httpClient: _FakeClient((request) {
        sentRequest = request;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'items': [
                      {'label': 'ChatGPT Pro', 'value': 'ChatGPT Pro'},
                      {'label': 'Cursor Pro', 'value': 'Cursor Pro'},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final items = await service.extract(
      config: const DeepSeekConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
      ),
      roomPrompt: '提取第一列',
      markdown: '| 服务名称 |\n| --- |\n| ChatGPT Pro |',
    );

    expect(
      sentRequest!.url.toString(),
      'https://api.deepseek.com/chat/completions',
    );
    expect(sentRequest!.headers['Authorization'], 'Bearer sk-test');
    expect(sentRequest!.headers['Content-Type'], contains('application/json'));
    expect(items.map((e) => e.value), ['ChatGPT Pro', 'Cursor Pro']);
  });

  test('deepseek quick extract accepts numeric values', () async {
    final service = DeepSeekQuickExtractService(
      store: _MemoryStore(),
      httpClient: _FakeClient((_) {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'items': [
                      {'label': 26042802, 'value': 26042802},
                      {'value': 26042804},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final items = await service.extract(
      config: const DeepSeekConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
      ),
      roomPrompt: '提取 ID 列',
      markdown: '| ID |\n| --- |\n| 26042802 |',
    );

    expect(items.map((e) => e.label), ['26042802', '26042804']);
    expect(items.map((e) => e.value), ['26042802', '26042804']);
  });

  test('deepseek quick extract sorts candidates by markdown order', () async {
    final service = DeepSeekQuickExtractService(
      store: _MemoryStore(),
      httpClient: _FakeClient((_) {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'items': [
                      {'label': '26042804 - 喂猫', 'value': 26042804},
                      {'label': '26042802 - 下载抖音热歌DJ', 'value': 26042802},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final items = await service.extract(
      config: const DeepSeekConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
      ),
      roomPrompt: '提取 ID 列',
      markdown: '''
| ID | 标题 |
| --- | --- |
| 26042802 | 下载抖音热歌DJ |
| 26042804 | 喂猫 |
''',
    );

    expect(items.map((e) => e.value), ['26042802', '26042804']);
  });

  test('deepseek quick extract preserves duplicate candidates', () async {
    final service = DeepSeekQuickExtractService(
      store: _MemoryStore(),
      httpClient: _FakeClient((_) {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'items': [
                      {'label': '26042802', 'value': 26042802},
                      {'label': '26042802', 'value': 26042802},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final items = await service.extract(
      config: const DeepSeekConfig(
        apiKey: 'sk-test',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-v4-flash',
      ),
      roomPrompt: '提取 ID 列',
      markdown: '| ID |\n| --- |\n| 26042802 |\n| 26042802 |',
    );

    expect(items.map((e) => e.value), ['26042802', '26042802']);
  });

  test(
    'deepseek quick extract reports raw content summary when parsed empty',
    () async {
      final service = DeepSeekQuickExtractService(
        store: _MemoryStore(),
        httpClient: _FakeClient((_) {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'items': [
                        {'name': 'ChatGPT Pro'},
                      ],
                    }),
                  },
                },
              ],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => service.extract(
          config: const DeepSeekConfig(
            apiKey: 'sk-test',
            baseUrl: 'https://api.deepseek.com',
            model: 'deepseek-v4-flash',
          ),
          roomPrompt: '提取第一列',
          markdown: '| 服务名称 |\n| --- |\n| ChatGPT Pro |',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('原始响应摘要'),
          ),
        ),
      );
    },
  );
}

class _MemoryStore implements DeepSeekConfigStore {
  DeepSeekConfig? config;

  @override
  Future<void> clear() async {
    config = null;
  }

  @override
  Future<DeepSeekConfig?> load() async {
    return config;
  }

  @override
  Future<void> save(DeepSeekConfig cfg) async {
    config = cfg;
  }
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final http.Response Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
