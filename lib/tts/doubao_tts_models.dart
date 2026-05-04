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
  final int speechRate;
  final int loudnessRate;
  final bool markdownFilterEnabled;
  final bool latexEnabled;
  final bool filterParentheses;
  final String explicitDialect;
  final int pitch;
  final List<String> contextTexts;

  const DoubaoTtsConfig({
    required this.enabled,
    this.authMode = DoubaoTtsAuthMode.apiKey,
    required this.apiKey,
    this.appId = '',
    this.accessKey = '',
    required this.resourceId,
    required this.speaker,
    this.speechRate = 0,
    this.loudnessRate = 0,
    this.markdownFilterEnabled = false,
    this.latexEnabled = false,
    this.filterParentheses = true,
    this.explicitDialect = '',
    this.pitch = 0,
    this.contextTexts = const [],
  });

  DoubaoTtsConfig copyWith({
    bool? enabled,
    DoubaoTtsAuthMode? authMode,
    String? apiKey,
    String? appId,
    String? accessKey,
    String? resourceId,
    String? speaker,
    int? speechRate,
    int? loudnessRate,
    bool? markdownFilterEnabled,
    bool? latexEnabled,
    bool? filterParentheses,
    String? explicitDialect,
    int? pitch,
    List<String>? contextTexts,
  }) {
    return DoubaoTtsConfig(
      enabled: enabled ?? this.enabled,
      authMode: authMode ?? this.authMode,
      apiKey: apiKey ?? this.apiKey,
      appId: appId ?? this.appId,
      accessKey: accessKey ?? this.accessKey,
      resourceId: resourceId ?? this.resourceId,
      speaker: speaker ?? this.speaker,
      speechRate: speechRate ?? this.speechRate,
      loudnessRate: loudnessRate ?? this.loudnessRate,
      markdownFilterEnabled:
          markdownFilterEnabled ?? this.markdownFilterEnabled,
      latexEnabled: latexEnabled ?? this.latexEnabled,
      filterParentheses: filterParentheses ?? this.filterParentheses,
      explicitDialect: explicitDialect ?? this.explicitDialect,
      pitch: pitch ?? this.pitch,
      contextTexts: contextTexts ?? this.contextTexts,
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
    'speechRate': speechRate,
    'loudnessRate': loudnessRate,
    'markdownFilterEnabled': markdownFilterEnabled,
    'latexEnabled': latexEnabled,
    'filterParentheses': filterParentheses,
    'explicitDialect': explicitDialect,
    'pitch': pitch,
    'contextTexts': contextTexts,
  };

  factory DoubaoTtsConfig.fromJson(Map<String, dynamic> j) {
    final rawContextTexts = j['contextTexts'];
    return DoubaoTtsConfig(
      enabled: j['enabled'] as bool? ?? false,
      authMode: doubaoTtsAuthModeFromJson(j['authMode']),
      apiKey: j['apiKey'] as String? ?? '',
      appId: j['appId'] as String? ?? '',
      accessKey: j['accessKey'] as String? ?? '',
      resourceId: j['resourceId'] as String? ?? 'seed-tts-2.0',
      speaker: j['speaker'] as String? ?? '',
      speechRate: j['speechRate'] as int? ?? 0,
      loudnessRate: j['loudnessRate'] as int? ?? 0,
      markdownFilterEnabled: j['markdownFilterEnabled'] as bool? ?? false,
      latexEnabled: j['latexEnabled'] as bool? ?? false,
      filterParentheses: j['filterParentheses'] as bool? ?? true,
      explicitDialect: j['explicitDialect'] as String? ?? '',
      pitch: j['pitch'] as int? ?? 0,
      contextTexts: rawContextTexts is List
          ? rawContextTexts.whereType<String>().toList(growable: false)
          : const [],
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
