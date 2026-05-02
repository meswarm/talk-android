enum DoubaoTtsAuthMode { apiKey, appToken }

String doubaoTtsAuthModeToJson(DoubaoTtsAuthMode mode) {
  return switch (mode) {
    DoubaoTtsAuthMode.apiKey => 'apiKey',
    DoubaoTtsAuthMode.appToken => 'appToken',
  };
}

DoubaoTtsAuthMode doubaoTtsAuthModeFromJson(Object? raw) {
  return raw == 'appToken'
      ? DoubaoTtsAuthMode.appToken
      : DoubaoTtsAuthMode.apiKey;
}

class DoubaoTtsConfig {
  final bool enabled;
  final DoubaoTtsAuthMode authMode;
  final String apiKey;
  final String appId;
  final String accessKey;
  final String resourceId;
  final String speaker;

  const DoubaoTtsConfig({
    required this.enabled,
    this.authMode = DoubaoTtsAuthMode.apiKey,
    required this.apiKey,
    this.appId = '',
    this.accessKey = '',
    required this.resourceId,
    required this.speaker,
  });

  DoubaoTtsConfig copyWith({
    bool? enabled,
    DoubaoTtsAuthMode? authMode,
    String? apiKey,
    String? appId,
    String? accessKey,
    String? resourceId,
    String? speaker,
  }) {
    return DoubaoTtsConfig(
      enabled: enabled ?? this.enabled,
      authMode: authMode ?? this.authMode,
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      accessKey: accessKey ?? this.accessKey,
      resourceId: resourceId ?? this.resourceId,
      speaker: speaker ?? this.speaker,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'authMode': doubaoTtsAuthModeToJson(authMode),
    'apiKey': apiKey,
    'appId': appId,
    'accessKey': accessKey,
    'resourceId': resourceId,
    'speaker': speaker,
  };

  factory DoubaoTtsConfig.fromJson(Map<String, dynamic> j) {
    return DoubaoTtsConfig(
      enabled: j['enabled'] as bool? ?? false,
      authMode: doubaoTtsAuthModeFromJson(j['authMode']),
      apiKey: j['apiKey'] as String? ?? '',
      appId: j['appId'] as String? ?? '',
      accessKey: j['accessKey'] as String? ?? '',
      resourceId: j['resourceId'] as String? ?? 'seed-tts-2.0',
      speaker: j['speaker'] as String? ?? '',
    );
  }

  bool get hasAuthConfig {
    return switch (authMode) {
      DoubaoTtsAuthMode.apiKey => apiKey.trim().isNotEmpty,
      DoubaoTtsAuthMode.appToken =>
        appId.trim().isNotEmpty && accessKey.trim().isNotEmpty,
    };
  }

  bool get isConfigured =>
      hasAuthConfig &&
      resourceId.trim().isNotEmpty &&
      speaker.trim().isNotEmpty;
}

enum DoubaoTtsPhase { loading, noStore, configured }
