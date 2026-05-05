import 'package:flutter_test/flutter_test.dart';
import 'package:talk/tts/doubao_tts_models.dart';

void main() {
  test('doubao tts config json roundtrip', () {
    const cfg = DoubaoTtsConfig(
      enabled: true,
      apiKey: 'k',
      resourceId: 'seed-tts-2.0',
      speaker: 'spk',
      speechRate: 12,
      loudnessRate: -6,
      markdownFilterEnabled: true,
      latexEnabled: true,
      filterParentheses: false,
      explicitDialect: 'sichuan',
      pitch: 3,
      contextTexts: ['你可以说慢一点吗？', '语气再欢乐一点'],
      announceMessageContent: true,
      contentEngine: VoiceAnnouncementContentEngine.realtimeDialog,
      qwenApiKey: 'qwen-key',
      qwenModel: 'qwen3.6-flash',
      qwenSystemPrompt: '整理消息',
      realtimeAppId: 'app-id',
      realtimeAppKey: 'app-key',
      realtimeAccessToken: 'token',
      realtimeResourceId: 'volc.speech.dialog',
      realtimeModel: '1.2.1.1',
      realtimeSpeaker: 'zh_female_vv_jupiter_bigtts',
      realtimeSystemRole: '你是播报助手',
      realtimeSpeakingStyle: '简短自然',
      realtimeSummaryPrompt: '请整理成一句提醒',
    );
    final decoded = DoubaoTtsConfig.fromJson(cfg.toJson());
    expect(decoded.enabled, isTrue);
    expect(decoded.authMode, DoubaoTtsAuthMode.apiKey);
    expect(decoded.apiKey, 'k');
    expect(decoded.resourceId, 'seed-tts-2.0');
    expect(decoded.speaker, 'spk');
    expect(decoded.speechRate, 12);
    expect(decoded.loudnessRate, -6);
    expect(decoded.markdownFilterEnabled, isTrue);
    expect(decoded.latexEnabled, isTrue);
    expect(decoded.filterParentheses, isFalse);
    expect(decoded.explicitDialect, 'sichuan');
    expect(decoded.pitch, 3);
    expect(decoded.contextTexts, ['你可以说慢一点吗？', '语气再欢乐一点']);
    expect(decoded.announceMessageContent, isTrue);
    expect(
      decoded.contentEngine,
      VoiceAnnouncementContentEngine.realtimeDialog,
    );
    expect(decoded.qwenApiKey, 'qwen-key');
    expect(decoded.qwenModel, 'qwen3.6-flash');
    expect(decoded.qwenSystemPrompt, '整理消息');
    expect(decoded.realtimeAppId, 'app-id');
    expect(decoded.realtimeAppKey, 'app-key');
    expect(decoded.realtimeAccessToken, 'token');
    expect(decoded.realtimeResourceId, 'volc.speech.dialog');
    expect(decoded.realtimeModel, '1.2.1.1');
    expect(decoded.realtimeSpeaker, 'zh_female_vv_jupiter_bigtts');
    expect(decoded.realtimeSystemRole, '你是播报助手');
    expect(decoded.realtimeSpeakingStyle, '简短自然');
    expect(decoded.realtimeSummaryPrompt, '请整理成一句提醒');
    expect(decoded.hasRealtimeDialogConfig, isTrue);
    expect(decoded.isConfigured, isTrue);
  });

  test('doubao tts config defaults and not configured', () {
    final decoded = DoubaoTtsConfig.fromJson(const <String, dynamic>{});
    expect(decoded.enabled, isFalse);
    expect(decoded.authMode, DoubaoTtsAuthMode.apiKey);
    expect(decoded.resourceId, 'seed-tts-2.0');
    expect(decoded.speechRate, 0);
    expect(decoded.loudnessRate, 0);
    expect(decoded.markdownFilterEnabled, isFalse);
    expect(decoded.latexEnabled, isFalse);
    expect(decoded.filterParentheses, isTrue);
    expect(decoded.explicitDialect, isEmpty);
    expect(decoded.pitch, 0);
    expect(decoded.contextTexts, isEmpty);
    expect(decoded.announceMessageContent, isFalse);
    expect(decoded.contentEngine, VoiceAnnouncementContentEngine.qwenTts);
    expect(decoded.qwenApiKey, isEmpty);
    expect(decoded.qwenModel, 'qwen3.6-flash');
    expect(decoded.qwenSystemPrompt, isNotEmpty);
    expect(decoded.realtimeAppId, isEmpty);
    expect(decoded.realtimeAppKey, isEmpty);
    expect(decoded.realtimeAccessToken, isEmpty);
    expect(decoded.realtimeResourceId, 'volc.speech.dialog');
    expect(decoded.realtimeModel, '1.2.1.1');
    expect(decoded.realtimeSpeaker, 'zh_female_vv_jupiter_bigtts');
    expect(decoded.realtimeSystemRole, isNotEmpty);
    expect(decoded.realtimeSpeakingStyle, isNotEmpty);
    expect(decoded.realtimeSummaryPrompt, isNotEmpty);
    expect(decoded.hasRealtimeDialogConfig, isFalse);
    expect(decoded.isConfigured, isFalse);
  });
}
