import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:talk/pages/realtime_secretary_settings_page.dart';
import 'package:talk/realtime_secretary/realtime_secretary_config_store.dart';
import 'package:talk/realtime_secretary/realtime_secretary_models.dart';
import 'package:talk/realtime_secretary/realtime_secretary_service.dart';
import 'package:talk/tts/doubao_tts_config_store.dart';
import 'package:talk/tts/doubao_tts_models.dart';
import 'package:talk/tts/doubao_tts_service.dart';

void main() {
  testWidgets('requires auth fields when enabling secretary', (tester) async {
    final secretary = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );
    await secretary.bootstrap();
    final tts = DoubaoTtsService(
      store: _MemoryTtsStore(),
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );

    await _pumpPage(tester, secretary: secretary, tts: tts);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用实时语音秘书'));
    await tester.pumpAndSettle();
    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(
      find.text('请填写 App ID、App Key、Access Token 与 Resource ID'),
      findsOneWidget,
    );
  });

  testWidgets('saves config and clamps numeric fields', (tester) async {
    final store = _MemorySecretaryStore();
    final secretary = RealtimeSecretaryService(
      store: store,
      bridge: _FakeSecretaryBridge(),
    );
    await secretary.bootstrap();
    final tts = DoubaoTtsService(
      store: _MemoryTtsStore(),
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );

    await _pumpPage(tester, secretary: secretary, tts: tts);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用实时语音秘书'));
    await tester.pumpAndSettle();
    await _enterTextByLabel(tester, 'App ID', 'app-id');
    await _enterTextByLabel(tester, 'App Key', 'app-key');
    await _enterTextByLabel(tester, 'Access Token', 'token');
    await _enterTextByLabel(tester, 'Resource ID', 'volc.speech.dialog');
    await _enterTextByLabel(tester, '秘书名称', '小智');
    await tester.tap(find.text('需要暗号确认'));
    await tester.pumpAndSettle();
    await _enterTextByLabel(tester, '系统角色', '你是一个谨慎的消息秘书。');
    await _enterTextByLabel(tester, '说话风格', '简洁、自然，不夸张。');
    await _enterTextByLabel(tester, '模型版本', '2.2.0.0');
    await _enterTextByLabel(tester, '说话人音色', 'zh_male_yunzhou_jupiter_bigtts');
    await _enterTextByLabel(tester, '语速', '999');
    await _enterTextByLabel(tester, '音量', '-999');
    await _enterTextByLabel(tester, '等待暗号时间（秒）', '99');
    await _enterTextByLabel(tester, '对话空闲超时（秒）', '99');
    await _enterTextByLabel(tester, '最近聊天上下文条数', '0');

    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(store.config!.enabled, isTrue);
    expect(store.config!.requireWakePhrase, isFalse);
    expect(store.config!.systemRole, '你是一个谨慎的消息秘书。');
    expect(store.config!.speakingStyle, '简洁、自然，不夸张。');
    expect(store.config!.model, '2.2.0.0');
    expect(store.config!.speaker, 'zh_male_yunzhou_jupiter_bigtts');
    expect(store.config!.speechRate, 100);
    expect(store.config!.loudnessRate, -50);
    expect(store.config!.wakeWaitSeconds, 30);
    expect(store.config!.activeChatIdleSeconds, 30);
    expect(store.config!.contextMessageCount, 1);
  });

  testWidgets('enabling secretary disables ordinary voice announcement', (
    tester,
  ) async {
    final secretary = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );
    await secretary.bootstrap();
    final ttsStore = _MemoryTtsStore();
    final tts = DoubaoTtsService(
      store: ttsStore,
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );
    await tts.saveConfig(
      const DoubaoTtsConfig(
        enabled: true,
        apiKey: 'api-key',
        resourceId: 'seed-tts-2.0',
        speaker: 'speaker-a',
      ),
    );

    await _pumpPage(tester, secretary: secretary, tts: tts);
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用实时语音秘书'));
    await tester.pumpAndSettle();
    await _enterTextByLabel(tester, 'App ID', 'app-id');
    await _enterTextByLabel(tester, 'App Key', 'app-key');
    await _enterTextByLabel(tester, 'Access Token', 'token');
    await _tapText(tester, '保存');
    await tester.pumpAndSettle();

    expect(ttsStore.config!.enabled, isFalse);
  });

  testWidgets('test config uses current form values without saving', (
    tester,
  ) async {
    final store = _MemorySecretaryStore();
    final bridge = _FakeSecretaryBridge();
    final secretary = RealtimeSecretaryService(store: store, bridge: bridge);
    await secretary.bootstrap();
    final tts = DoubaoTtsService(
      store: _MemoryTtsStore(),
      httpClient: _FakeClient(),
      customAudioPlayer: (_) async {},
    );

    await _pumpPage(tester, secretary: secretary, tts: tts);
    await tester.pumpAndSettle();

    await _enterTextByLabel(tester, 'App ID', 'app-id');
    await _enterTextByLabel(tester, 'App Key', 'app-key');
    await _enterTextByLabel(tester, 'Access Token', 'token');
    await _tapText(tester, '测试配置');
    await tester.pumpAndSettle();

    expect(store.config, isNull);
    expect(bridge.testConfigs.single.appId, 'app-id');
    expect(find.text('测试已启动，如果配置正确会听到测试提示音'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required RealtimeSecretaryService secretary,
  required DoubaoTtsService tts,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RealtimeSecretaryService>.value(
          value: secretary,
        ),
        ChangeNotifierProvider<DoubaoTtsService>.value(value: tts),
      ],
      child: const MaterialApp(home: RealtimeSecretarySettingsPage()),
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

class _MemorySecretaryStore implements RealtimeSecretaryConfigStore {
  RealtimeSecretaryConfig? config;

  @override
  Future<void> clear() async {
    config = null;
  }

  @override
  Future<RealtimeSecretaryConfig?> load() async => config;

  @override
  Future<void> save(RealtimeSecretaryConfig config) async {
    this.config = config;
  }
}

class _MemoryTtsStore implements DoubaoTtsConfigStore {
  DoubaoTtsConfig? config;

  @override
  Future<void> clear() async {
    config = null;
  }

  @override
  Future<DoubaoTtsConfig?> load() async => config;

  @override
  Future<void> save(DoubaoTtsConfig config) async {
    this.config = config;
  }
}

class _FakeSecretaryBridge implements RealtimeSecretaryBridge {
  final testConfigs = <RealtimeSecretaryConfig>[];

  @override
  Future<bool> isServiceRunning() async => false;

  @override
  Future<void> sendContextTextQuery(String text) async {}

  @override
  Future<void> startForegroundService(RealtimeSecretaryConfig config) async {}

  @override
  Future<void> testConfig(RealtimeSecretaryConfig config) async {
    testConfigs.add(config);
  }

  @override
  Future<void> startWakeSession({
    required RealtimeSecretaryConfig config,
    required String roomId,
    required String openingAnnouncement,
    String? initialContextText,
  }) async {}

  @override
  Future<void> stopForegroundService() async {}

  @override
  Future<void> stopSession() async {}
}

class _FakeClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }
}
