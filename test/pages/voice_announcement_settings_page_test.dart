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

    await _tapText(tester, '启用新消息语音播报');
    await _tapText(tester, '播报消息内容');

    await _enterTextByLabel(tester, 'Qwen API Key', 'qwen-key-123');
    await _enterTextByLabel(tester, 'Qwen 模型', 'qwen3.6-flash');
    await _enterTextByLabel(tester, '消息整理系统提示词', '请整理成一句话');
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
    expect(store.config!.announceMessageContent, isTrue);
    expect(store.config!.qwenApiKey, 'qwen-key-123');
    expect(store.config!.qwenModel, 'qwen3.6-flash');
    expect(store.config!.qwenSystemPrompt, '请整理成一句话');
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

  testWidgets(
    'requires qwen key when message content announcement is enabled',
    (tester) async {
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

      await _tapText(tester, '播报消息内容');
      await _enterTextByLabel(tester, '豆包 API Key', 'api-key-123');
      await _enterTextByLabel(tester, 'Resource ID', 'seed-tts-2.0');
      await _enterTextByLabel(tester, 'Speaker', 'speaker-a');
      await _tapText(tester, '保存');
      await tester.pumpAndSettle();

      expect(find.text('开启播报消息内容时，请填写 Qwen API Key'), findsOneWidget);
      expect(store.config, isNull);
    },
  );

  testWidgets('saves realtime dialog content engine config', (tester) async {
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

    await _tapText(tester, '播报消息内容');
    await _selectDropdownText(tester, '豆包实时语音大模型');
    await _enterTextByLabel(tester, '实时语音 App ID', 'app-id');
    await _enterTextByLabel(tester, '实时语音 App Key', 'app-key');
    await _enterTextByLabel(tester, '实时语音 Access Token', 'token');
    await _enterTextByLabel(tester, '实时语音 Resource ID', 'volc.speech.dialog');
    await _enterTextByLabel(tester, '实时语音模型', '1.2.1.1');
    await _enterTextByLabel(tester, '实时语音音色', 'zh_female_vv_jupiter_bigtts');
    await _enterTextByLabel(tester, '实时语音系统提示词', '你是播报助手');
    await _enterTextByLabel(tester, '实时语音说话风格', '简短自然');
    await _enterTextByLabel(tester, '实时语音播报整理指令', '请整理成一句提醒');
    await _enterTextByLabel(tester, '豆包 API Key', 'api-key-123');
    await _enterTextByLabel(tester, 'Resource ID', 'seed-tts-2.0');
    await _enterTextByLabel(tester, 'Speaker', 'speaker-a');
    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(
      store.config!.contentEngine,
      VoiceAnnouncementContentEngine.realtimeDialog,
    );
    expect(store.config!.realtimeAppId, 'app-id');
    expect(store.config!.realtimeAppKey, 'app-key');
    expect(store.config!.realtimeAccessToken, 'token');
    expect(store.config!.realtimeResourceId, 'volc.speech.dialog');
    expect(store.config!.realtimeModel, '1.2.1.1');
    expect(store.config!.realtimeSpeaker, 'zh_female_vv_jupiter_bigtts');
    expect(store.config!.realtimeSystemRole, '你是播报助手');
    expect(store.config!.realtimeSpeakingStyle, '简短自然');
    expect(store.config!.realtimeSummaryPrompt, '请整理成一句提醒');
  });

  testWidgets(
    'requires realtime credentials when realtime content engine is selected',
    (tester) async {
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

      await _tapText(tester, '播报消息内容');
      await _selectDropdownText(tester, '豆包实时语音大模型');
      await _enterTextByLabel(tester, '豆包 API Key', 'api-key-123');
      await _enterTextByLabel(tester, 'Resource ID', 'seed-tts-2.0');
      await _enterTextByLabel(tester, 'Speaker', 'speaker-a');
      await _tapText(tester, '保存');
      await tester.pumpAndSettle();

      expect(
        find.text('请填写实时语音 App ID、App Key 与 Access Token'),
        findsOneWidget,
      );
      expect(store.config, isNull);
    },
  );

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
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownText(WidgetTester tester, String text) async {
  var finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    finder = find.byType(
      DropdownButtonFormField<VoiceAnnouncementContentEngine>,
    );
  }
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
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
