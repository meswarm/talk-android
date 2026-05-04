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
    expect(decoded.isConfigured, isFalse);
  });
}
