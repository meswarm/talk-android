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

    expect(
      find.text('请填写 APP ID、Access Token、Resource ID 与 Speaker'),
      findsOneWidget,
    );
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

    await _enterTextByLabel(tester, 'APP ID', '3569823009');
    await _enterTextByLabel(tester, 'Access Token', 'token-123');
    await _enterTextByLabel(tester, 'Resource ID', 'seed-tts-2.0');
    await _enterTextByLabel(tester, 'Speaker', 'speaker-a');

    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(store.config!.enabled, isTrue);
    expect(store.config!.authMode, DoubaoTtsAuthMode.appToken);
    expect(store.config!.appId, '3569823009');
    expect(store.config!.accessKey, 'token-123');
    expect(store.config!.resourceId, 'seed-tts-2.0');
    expect(store.config!.speaker, 'speaker-a');
  });

  testWidgets('disables keep-alive switch until voice announcement is configured', (
    tester,
  ) async {
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
  });

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
        authMode: DoubaoTtsAuthMode.appToken,
        apiKey: '',
        appId: 'app-id',
        accessKey: 'access-token',
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
