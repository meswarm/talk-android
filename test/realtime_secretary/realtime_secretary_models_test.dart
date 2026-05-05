import 'package:flutter_test/flutter_test.dart';
import 'package:talk/realtime_secretary/realtime_secretary_models.dart';

void main() {
  test('realtime secretary config json roundtrip', () {
    const cfg = RealtimeSecretaryConfig(
      enabled: true,
      appId: 'app-id',
      appKey: 'app-key',
      accessToken: 'token',
      resourceId: 'volc.speech.dialog',
      secretaryName: '小智',
      requireWakePhrase: false,
      systemRole: '你是一个谨慎的消息秘书。',
      speakingStyle: '简洁、自然，不夸张。',
      model: '1.2.1.1',
      speaker: 'zh_female_vv_jupiter_bigtts',
      speechRate: 12,
      loudnessRate: -8,
      wakeWaitSeconds: 12,
      activeChatIdleSeconds: 10,
      contextMessageCount: 5,
    );

    final decoded = RealtimeSecretaryConfig.fromJson(cfg.toJson());

    expect(decoded.enabled, isTrue);
    expect(decoded.appId, 'app-id');
    expect(decoded.appKey, 'app-key');
    expect(decoded.accessToken, 'token');
    expect(decoded.resourceId, 'volc.speech.dialog');
    expect(decoded.secretaryName, '小智');
    expect(decoded.requireWakePhrase, isFalse);
    expect(decoded.systemRole, '你是一个谨慎的消息秘书。');
    expect(decoded.speakingStyle, '简洁、自然，不夸张。');
    expect(decoded.model, '1.2.1.1');
    expect(decoded.speaker, 'zh_female_vv_jupiter_bigtts');
    expect(decoded.speechRate, 12);
    expect(decoded.loudnessRate, -8);
    expect(decoded.wakeWaitSeconds, 12);
    expect(decoded.activeChatIdleSeconds, 10);
    expect(decoded.contextMessageCount, 5);
    expect(decoded.isConfigured, isTrue);
  });

  test('realtime secretary config defaults and clamps', () {
    final decoded = RealtimeSecretaryConfig.fromJson(const <String, dynamic>{
      'wakeWaitSeconds': 99,
      'contextMessageCount': 0,
      'speechRate': 999,
      'loudnessRate': -999,
      'activeChatIdleSeconds': 99,
    });

    expect(decoded.enabled, isFalse);
    expect(decoded.resourceId, 'volc.speech.dialog');
    expect(decoded.secretaryName, '小智');
    expect(decoded.requireWakePhrase, isTrue);
    expect(decoded.systemRole, '');
    expect(decoded.speakingStyle, '');
    expect(decoded.model, '1.2.1.1');
    expect(decoded.speaker, 'zh_female_vv_jupiter_bigtts');
    expect(decoded.speechRate, 100);
    expect(decoded.loudnessRate, -50);
    expect(decoded.wakeWaitSeconds, 30);
    expect(decoded.activeChatIdleSeconds, 30);
    expect(decoded.contextMessageCount, 1);
    expect(decoded.isConfigured, isFalse);
  });
}
