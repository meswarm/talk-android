import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/keep_alive/keep_alive_controller.dart';
import 'package:talk/keep_alive/keep_alive_service_bridge.dart';
import 'package:talk/pages/voice_announcement_settings_page.dart';
import 'package:talk/services/local_storage.dart';
import 'package:talk/tts/doubao_tts_config_store.dart';
import 'package:talk/tts/doubao_tts_models.dart';
import 'package:talk/tts/doubao_tts_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  testWidgets('shows required-field error when saving empty config', (
    tester,
  ) async {
    final store = _MemoryStore();
    final svc = DoubaoTtsService(
      store: store,
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );
    await svc.bootstrap();
    final keepAlive = KeepAliveController(bridge: _FakeKeepAliveBridge());
    await keepAlive.bootstrap();

    await _pumpPage(tester, tts: svc, keepAlive: keepAlive);
    await tester.pumpAndSettle();

    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(find.text('请填写 API Key、Resource ID 与 Speaker'), findsOneWidget);
    expect(find.text('服务接口认证信息'), findsNothing);
    expect(find.text('新版 API Key'), findsNothing);
  });

  testWidgets('saves config from form fields', (tester) async {
    final store = _MemoryStore();
    final svc = DoubaoTtsService(
      store: store,
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );
    await svc.bootstrap();
    final keepAlive = KeepAliveController(bridge: _FakeKeepAliveBridge());
    await keepAlive.bootstrap();

    await _pumpPage(tester, tts: svc, keepAlive: keepAlive);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用新消息语音播报'));
    await tester.pumpAndSettle();

    await _enterTextByLabel(tester, '豆包 API Key', 'api-key-123');
    await _enterTextByLabel(tester, 'Resource ID', 'seed-tts-2.0');
    await _enterTextByLabel(tester, 'Speaker', 'speaker-a');
    await _enterTextByLabel(tester, '语速', '25');
    await _enterTextByLabel(tester, '音量', '-10');
    await _tapText(tester, 'Markdown 解析过滤');
    await _tapText(tester, '播报 LaTeX 公式');
    await _tapText(tester, '过滤括号内的部分');
    await _enterTextByLabel(tester, '音调取值', '4');
    await _enterTextByLabel(tester, '语音合成辅助信息', '你可以说慢一点吗？\n语气再欢乐一点');

    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(store.config!.enabled, isTrue);
    expect(store.config!.authMode, DoubaoTtsAuthMode.apiKey);
    expect(store.config!.apiKey, 'api-key-123');
    expect(store.config!.appId, isEmpty);
    expect(store.config!.accessKey, isEmpty);
    expect(store.config!.resourceId, 'seed-tts-2.0');
    expect(store.config!.speaker, 'speaker-a');
    expect(store.config!.speechRate, 25);
    expect(store.config!.loudnessRate, -10);
    expect(store.config!.markdownFilterEnabled, isTrue);
    expect(store.config!.latexEnabled, isTrue);
    expect(store.config!.filterParentheses, isFalse);
    expect(store.config!.pitch, 4);
    expect(store.config!.contextTexts, ['你可以说慢一点吗？', '语气再欢乐一点']);
  });

  testWidgets('enable switch persists immediately for saved config', (
    tester,
  ) async {
    final store = _MemoryStore();
    final svc = DoubaoTtsService(
      store: store,
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: false,
        apiKey: 'api-key',
        resourceId: 'seed-tts-2.0',
        speaker: 'speaker-a',
      ),
    );
    final keepAlive = KeepAliveController(bridge: _FakeKeepAliveBridge());
    await keepAlive.bootstrap();

    await _pumpPage(tester, tts: svc, keepAlive: keepAlive);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用新消息语音播报'));
    await tester.pumpAndSettle();

    expect(store.config!.enabled, isTrue);
    expect(svc.enabled, isTrue);
  });

  testWidgets(
    'disables keep-alive switch until voice announcement is configured',
    (tester) async {
      final store = _MemoryStore();
      final svc = DoubaoTtsService(
        store: store,
        httpClient: _FakeClient(),
        customAudioPlayer: (_) async {},
      );
      await svc.bootstrap();
      final bridge = _FakeKeepAliveBridge();
      final keepAlive = KeepAliveController(bridge: bridge);
      await keepAlive.bootstrap();

      await _pumpPage(tester, tts: svc, keepAlive: keepAlive);
      await tester.pumpAndSettle();

      expect(find.text('常驻监听模式'), findsOneWidget);
      expect(find.text('先保存可用的语音播报配置后才能开启。'), findsOneWidget);

      await tester.tap(find.text('启用常驻监听模式'));
      await tester.pumpAndSettle();

      expect(bridge.startCount, 0);
      expect(keepAlive.enabled, isFalse);
    },
  );

  testWidgets('starts keep-alive service from settings page', (tester) async {
    final store = _MemoryStore();
    final svc = DoubaoTtsService(
      store: store,
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );
    await svc.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        authMode: DoubaoTtsAuthMode.apiKey,
        apiKey: 'api-key',
        resourceId: 'seed-tts-2.0',
        speaker: 'speaker-a',
      ),
    );
    final bridge = _FakeKeepAliveBridge();
    final keepAlive = KeepAliveController(bridge: bridge);
    await keepAlive.bootstrap();

    await _pumpPage(tester, tts: svc, keepAlive: keepAlive);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用常驻监听模式'));
    await tester.pumpAndSettle();

    expect(bridge.startCount, 1);
    expect(keepAlive.enabled, isTrue);
    expect(find.text('常驻监听中'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required DoubaoTtsService tts,
  required KeepAliveController keepAlive,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DoubaoTtsService>.value(value: tts),
        ChangeNotifierProvider<KeepAliveController>.value(value: keepAlive),
      ],
      child: const MaterialApp(home: VoiceAnnouncementSettingsPage()),
    ),
  );
}

Future<void> _enterTextByLabel(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(TextField),
  );
  await tester.scrollUntilVisible(
    field,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(field), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
  Future<void> save(DoubaoTtsConfig config) async {
    this.config = config;
  }
}

class _FakeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}

class _FakeKeepAliveBridge implements KeepAliveServiceBridge {
  var running = false;
  var startCount = 0;
  var stopCount = 0;
  var openSettingsCount = 0;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> openBatteryOptimizationSettings() async {
    openSettingsCount += 1;
  }

  @override
  Future<void> start() async {
    startCount += 1;
    running = true;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    running = false;
  }
}
