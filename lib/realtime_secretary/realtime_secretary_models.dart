const defaultRealtimeSecretaryResourceId = 'volc.speech.dialog';
const defaultRealtimeSecretaryName = '小智';
const defaultRealtimeSecretaryModel = '1.2.1.1';
const defaultRealtimeSecretarySpeaker = 'zh_female_vv_jupiter_bigtts';
const defaultRealtimeSecretarySpeechRate = 0;
const minRealtimeSecretarySpeechRate = -50;
const maxRealtimeSecretarySpeechRate = 100;
const defaultRealtimeSecretaryLoudnessRate = 0;
const minRealtimeSecretaryLoudnessRate = -50;
const maxRealtimeSecretaryLoudnessRate = 100;
const defaultRealtimeSecretaryWakeWaitSeconds = 15;
const minRealtimeSecretaryWakeWaitSeconds = 5;
const maxRealtimeSecretaryWakeWaitSeconds = 30;
const defaultRealtimeSecretaryActiveChatIdleSeconds = 10;
const minRealtimeSecretaryActiveChatIdleSeconds = 5;
const maxRealtimeSecretaryActiveChatIdleSeconds = 30;
const defaultRealtimeSecretaryContextMessageCount = 3;
const minRealtimeSecretaryContextMessageCount = 1;
const maxRealtimeSecretaryContextMessageCount = 10;

class RealtimeSecretaryConfig {
  final bool enabled;
  final String appId;
  final String appKey;
  final String accessToken;
  final String resourceId;
  final String secretaryName;
  final bool requireWakePhrase;
  final String systemRole;
  final String speakingStyle;
  final String model;
  final String speaker;
  final int speechRate;
  final int loudnessRate;
  final int wakeWaitSeconds;
  final int activeChatIdleSeconds;
  final int contextMessageCount;

  const RealtimeSecretaryConfig({
    required this.enabled,
    required this.appId,
    required this.appKey,
    required this.accessToken,
    this.resourceId = defaultRealtimeSecretaryResourceId,
    this.secretaryName = defaultRealtimeSecretaryName,
    this.requireWakePhrase = true,
    this.systemRole = '',
    this.speakingStyle = '',
    this.model = defaultRealtimeSecretaryModel,
    this.speaker = defaultRealtimeSecretarySpeaker,
    this.speechRate = defaultRealtimeSecretarySpeechRate,
    this.loudnessRate = defaultRealtimeSecretaryLoudnessRate,
    this.wakeWaitSeconds = defaultRealtimeSecretaryWakeWaitSeconds,
    this.activeChatIdleSeconds = defaultRealtimeSecretaryActiveChatIdleSeconds,
    this.contextMessageCount = defaultRealtimeSecretaryContextMessageCount,
  });

  RealtimeSecretaryConfig copyWith({
    bool? enabled,
    String? appId,
    String? appKey,
    String? accessToken,
    String? resourceId,
    String? secretaryName,
    bool? requireWakePhrase,
    String? systemRole,
    String? speakingStyle,
    String? model,
    String? speaker,
    int? speechRate,
    int? loudnessRate,
    int? wakeWaitSeconds,
    int? activeChatIdleSeconds,
    int? contextMessageCount,
  }) {
    return RealtimeSecretaryConfig(
      enabled: enabled ?? this.enabled,
      appId: appId ?? this.appId,
      appKey: appKey ?? this.appKey,
      accessToken: accessToken ?? this.accessToken,
      resourceId: resourceId ?? this.resourceId,
      secretaryName: secretaryName ?? this.secretaryName,
      requireWakePhrase: requireWakePhrase ?? this.requireWakePhrase,
      systemRole: systemRole ?? this.systemRole,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      model: model ?? this.model,
      speaker: speaker ?? this.speaker,
      speechRate: speechRate ?? this.speechRate,
      loudnessRate: loudnessRate ?? this.loudnessRate,
      wakeWaitSeconds: wakeWaitSeconds ?? this.wakeWaitSeconds,
      activeChatIdleSeconds:
          activeChatIdleSeconds ?? this.activeChatIdleSeconds,
      contextMessageCount: contextMessageCount ?? this.contextMessageCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'appId': appId,
    'appKey': appKey,
    'accessToken': accessToken,
    'resourceId': resourceId,
    'secretaryName': secretaryName,
    'requireWakePhrase': requireWakePhrase,
    'systemRole': systemRole,
    'speakingStyle': speakingStyle,
    'model': model,
    'speaker': speaker,
    'speechRate': speechRate,
    'loudnessRate': loudnessRate,
    'wakeWaitSeconds': wakeWaitSeconds,
    'activeChatIdleSeconds': activeChatIdleSeconds,
    'contextMessageCount': contextMessageCount,
  };

  factory RealtimeSecretaryConfig.fromJson(Map<String, dynamic> j) {
    return RealtimeSecretaryConfig(
      enabled: j['enabled'] as bool? ?? false,
      appId: j['appId'] as String? ?? '',
      appKey: j['appKey'] as String? ?? '',
      accessToken: j['accessToken'] as String? ?? '',
      resourceId: (j['resourceId'] as String?)?.trim().isNotEmpty == true
          ? j['resourceId'] as String
          : defaultRealtimeSecretaryResourceId,
      secretaryName: (j['secretaryName'] as String?)?.trim().isNotEmpty == true
          ? j['secretaryName'] as String
          : defaultRealtimeSecretaryName,
      requireWakePhrase: j['requireWakePhrase'] as bool? ?? true,
      systemRole: j['systemRole'] as String? ?? '',
      speakingStyle: j['speakingStyle'] as String? ?? '',
      model: (j['model'] as String?)?.trim().isNotEmpty == true
          ? j['model'] as String
          : defaultRealtimeSecretaryModel,
      speaker: (j['speaker'] as String?)?.trim().isNotEmpty == true
          ? j['speaker'] as String
          : defaultRealtimeSecretarySpeaker,
      speechRate: _intFromJson(
        j['speechRate'],
        defaultRealtimeSecretarySpeechRate,
        minRealtimeSecretarySpeechRate,
        maxRealtimeSecretarySpeechRate,
      ),
      loudnessRate: _intFromJson(
        j['loudnessRate'],
        defaultRealtimeSecretaryLoudnessRate,
        minRealtimeSecretaryLoudnessRate,
        maxRealtimeSecretaryLoudnessRate,
      ),
      wakeWaitSeconds: _intFromJson(
        j['wakeWaitSeconds'],
        defaultRealtimeSecretaryWakeWaitSeconds,
        minRealtimeSecretaryWakeWaitSeconds,
        maxRealtimeSecretaryWakeWaitSeconds,
      ),
      activeChatIdleSeconds: _intFromJson(
        j['activeChatIdleSeconds'],
        defaultRealtimeSecretaryActiveChatIdleSeconds,
        minRealtimeSecretaryActiveChatIdleSeconds,
        maxRealtimeSecretaryActiveChatIdleSeconds,
      ),
      contextMessageCount: _intFromJson(
        j['contextMessageCount'],
        defaultRealtimeSecretaryContextMessageCount,
        minRealtimeSecretaryContextMessageCount,
        maxRealtimeSecretaryContextMessageCount,
      ),
    );
  }

  bool get isConfigured =>
      appId.trim().isNotEmpty &&
      appKey.trim().isNotEmpty &&
      accessToken.trim().isNotEmpty &&
      resourceId.trim().isNotEmpty;
}

class SecretaryTextBubble {
  final String senderName;
  final String body;

  const SecretaryTextBubble({required this.senderName, required this.body});
}

int _intFromJson(Object? raw, int fallback, int min, int max) {
  final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  return (value ?? fallback).clamp(min, max);
}
