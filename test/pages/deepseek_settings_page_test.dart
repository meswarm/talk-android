import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:talk/pages/deepseek_settings_page.dart';
import 'package:talk/quick_extract/deepseek_config.dart';
import 'package:talk/quick_extract/deepseek_config_store.dart';
import 'package:talk/quick_extract/deepseek_quick_extract_service.dart';

void main() {
  testWidgets('deepseek settings page saves config', (tester) async {
    final store = _MemoryStore();
    final service = DeepSeekQuickExtractService(
      store: store,
      httpClient: _FakeClient(),
    );
    await service.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<DeepSeekQuickExtractService>.value(
        value: service,
        child: const MaterialApp(home: DeepSeekSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DeepSeek 配置'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'deepseek-v4-flash'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(store.config!.apiKey, 'sk-test');
    expect(store.config!.model, 'deepseek-v4-flash');
  });
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
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}
