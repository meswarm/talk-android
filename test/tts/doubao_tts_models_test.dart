import 'package:flutter_test/flutter_test.dart';
import 'package:talk/tts/doubao_tts_models.dart';

void main() {
  test('doubao tts config json roundtrip', () {
    const cfg = DoubaoTtsConfig(
      enabled: true,
      apiKey: 'k',
      resourceId: 'seed-tts-2.0',
      speaker: 'spk',
    );
    final decoded = DoubaoTtsConfig.fromJson(cfg.toJson());
    expect(decoded.enabled, isTrue);
    expect(decoded.authMode, DoubaoTtsAuthMode.apiKey);
    expect(decoded.apiKey, 'k');
    expect(decoded.resourceId, 'seed-tts-2.0');
    expect(decoded.speaker, 'spk');
    expect(decoded.isConfigured, isTrue);
  });

  test('doubao tts config defaults and not configured', () {
    final decoded = DoubaoTtsConfig.fromJson(const <String, dynamic>{});
    expect(decoded.enabled, isFalse);
    expect(decoded.authMode, DoubaoTtsAuthMode.apiKey);
    expect(decoded.resourceId, 'seed-tts-2.0');
    expect(decoded.isConfigured, isFalse);
  });
}
