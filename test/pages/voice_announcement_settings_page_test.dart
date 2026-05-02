import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:talk/pages/voice_announcement_settings_page.dart';
import 'package:talk/tts/doubao_tts_config_store.dart';
import 'package:talk/tts/doubao_tts_models.dart';
import 'package:talk/tts/doubao_tts_service.dart';

void main() {
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

    await tester.pumpWidget(
      ChangeNotifierProvider<DoubaoTtsService>.value(
        value: svc,
        child: const MaterialApp(home: VoiceAnnouncementSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
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

    await tester.pumpWidget(
      ChangeNotifierProvider<DoubaoTtsService>.value(
        value: svc,
        child: const MaterialApp(home: VoiceAnnouncementSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '3569823009');
    await tester.enterText(find.byType(TextField).at(1), 'token-123');
    await tester.enterText(find.byType(TextField).at(2), 'seed-tts-2.0');
    await tester.enterText(find.byType(TextField).at(3), 'speaker-a');
    await tester.tap(find.text('启用新消息语音播报'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(store.config, isNotNull);
    expect(store.config!.enabled, isTrue);
    expect(store.config!.authMode, DoubaoTtsAuthMode.appToken);
    expect(store.config!.appId, '3569823009');
    expect(store.config!.accessKey, 'token-123');
    expect(store.config!.resourceId, 'seed-tts-2.0');
    expect(store.config!.speaker, 'speaker-a');
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
