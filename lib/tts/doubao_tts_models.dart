enum DoubaoTtsAuthMode { apiKey, appToken }

enum VoiceAnnouncementContentEngine { qwenTts, realtimeDialog }

const defaultVoiceAnnouncementSummaryModel = 'qwen3.6-flash';
const defaultVoiceAnnouncementRealtimeResourceId = 'volc.speech.dialog';
const defaultVoiceAnnouncementRealtimeModel = '1.2.1.1';
const defaultVoiceAnnouncementRealtimeSpeaker = 'zh_female_vv_jupiter_bigtts';
const defaultVoiceAnnouncementRealtimeSystemRole =
    '你是 Talk 的消息语音播报助手。你只负责把收到的聊天消息整理成适合语音播放的简短提醒，不主动追问，不延展闲聊。';
const defaultVoiceAnnouncementRealtimeSpeakingStyle =
    '语气自然、简洁、像手机通知提醒。不要寒暄，不要说你收到了，不要问用户是否需要继续。';
const defaultVoiceAnnouncementRealtimeSummaryPrompt =
    '请把下面这条聊天消息整理成一句适合语音播报的简短中文摘要。'
    '只说摘要内容，不要说“发来消息”“新消息”，不要说房间名或发送者名称。'
    '不要逐条朗读长列表，优先总结数量、主题和重要事项；不要编造消息中没有的信息。';
const defaultVoiceAnnouncementSummarySystemPrompt =
    '你是消息语音播报整理助手。请把用户收到的一条聊天消息整理成适合语音播报的简短中文摘要。'
    '不要逐条朗读长列表，优先总结数量、主题和重要事项；不要编造消息中没有的信息；不要使用 Markdown。'
    '只输出消息内容摘要本身，不要包含房间名、发送者名称、“发来消息”、“新消息”等通知前缀。';

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

String voiceAnnouncementContentEngineToJson(
  VoiceAnnouncementContentEngine engine,
) {
  return switch (engine) {
    VoiceAnnouncementContentEngine.qwenTts => 'qwenTts',
    VoiceAnnouncementContentEngine.realtimeDialog => 'realtimeDialog',
  };
}

VoiceAnnouncementContentEngine voiceAnnouncementContentEngineFromJson(
  Object? raw,
) {
  return raw == 'realtimeDialog'
      ? VoiceAnnouncementContentEngine.realtimeDialog
      : VoiceAnnouncementContentEngine.qwenTts;
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
  final bool announceMessageContent;
  final VoiceAnnouncementContentEngine contentEngine;
  final String qwenApiKey;
  final String qwenModel;
  final String qwenSystemPrompt;
  final String realtimeAppId;
  final String realtimeAppKey;
  final String realtimeAccessToken;
  final String realtimeResourceId;
  final String realtimeModel;
  final String realtimeSpeaker;
  final String realtimeSystemRole;
  final String realtimeSpeakingStyle;
  final String realtimeSummaryPrompt;

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
    this.announceMessageContent = false,
    this.contentEngine = VoiceAnnouncementContentEngine.qwenTts,
    this.qwenApiKey = '',
    this.qwenModel = defaultVoiceAnnouncementSummaryModel,
    this.qwenSystemPrompt = defaultVoiceAnnouncementSummarySystemPrompt,
    this.realtimeAppId = '',
    this.realtimeAppKey = '',
    this.realtimeAccessToken = '',
    this.realtimeResourceId = defaultVoiceAnnouncementRealtimeResourceId,
    this.realtimeModel = defaultVoiceAnnouncementRealtimeModel,
    this.realtimeSpeaker = defaultVoiceAnnouncementRealtimeSpeaker,
    this.realtimeSystemRole = defaultVoiceAnnouncementRealtimeSystemRole,
    this.realtimeSpeakingStyle = defaultVoiceAnnouncementRealtimeSpeakingStyle,
    this.realtimeSummaryPrompt = defaultVoiceAnnouncementRealtimeSummaryPrompt,
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
    bool? announceMessageContent,
    VoiceAnnouncementContentEngine? contentEngine,
    String? qwenApiKey,
    String? qwenModel,
    String? qwenSystemPrompt,
    String? realtimeAppId,
    String? realtimeAppKey,
    String? realtimeAccessToken,
    String? realtimeResourceId,
    String? realtimeModel,
    String? realtimeSpeaker,
    String? realtimeSystemRole,
    String? realtimeSpeakingStyle,
    String? realtimeSummaryPrompt,
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
      announceMessageContent:
          announceMessageContent ?? this.announceMessageContent,
      contentEngine: contentEngine ?? this.contentEngine,
      qwenApiKey: qwenApiKey ?? this.qwenApiKey,
      qwenModel: qwenModel ?? this.qwenModel,
      qwenSystemPrompt: qwenSystemPrompt ?? this.qwenSystemPrompt,
      realtimeAppId: realtimeAppId ?? this.realtimeAppId,
      realtimeAppKey: realtimeAppKey ?? this.realtimeAppKey,
      realtimeAccessToken: realtimeAccessToken ?? this.realtimeAccessToken,
      realtimeResourceId: realtimeResourceId ?? this.realtimeResourceId,
      realtimeModel: realtimeModel ?? this.realtimeModel,
      realtimeSpeaker: realtimeSpeaker ?? this.realtimeSpeaker,
      realtimeSystemRole: realtimeSystemRole ?? this.realtimeSystemRole,
      realtimeSpeakingStyle:
          realtimeSpeakingStyle ?? this.realtimeSpeakingStyle,
      realtimeSummaryPrompt:
          realtimeSummaryPrompt ?? this.realtimeSummaryPrompt,
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
    'announceMessageContent': announceMessageContent,
    'contentEngine': voiceAnnouncementContentEngineToJson(contentEngine),
    'qwenApiKey': qwenApiKey,
    'qwenModel': qwenModel,
    'qwenSystemPrompt': qwenSystemPrompt,
    'realtimeAppId': realtimeAppId,
    'realtimeAppKey': realtimeAppKey,
    'realtimeAccessToken': realtimeAccessToken,
    'realtimeResourceId': realtimeResourceId,
    'realtimeModel': realtimeModel,
    'realtimeSpeaker': realtimeSpeaker,
    'realtimeSystemRole': realtimeSystemRole,
    'realtimeSpeakingStyle': realtimeSpeakingStyle,
    'realtimeSummaryPrompt': realtimeSummaryPrompt,
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
      announceMessageContent: j['announceMessageContent'] as bool? ?? false,
      contentEngine: voiceAnnouncementContentEngineFromJson(j['contentEngine']),
      qwenApiKey: j['qwenApiKey'] as String? ?? '',
      qwenModel: (j['qwenModel'] as String?)?.trim().isNotEmpty == true
          ? j['qwenModel'] as String
          : defaultVoiceAnnouncementSummaryModel,
      qwenSystemPrompt:
          (j['qwenSystemPrompt'] as String?)?.trim().isNotEmpty == true
          ? j['qwenSystemPrompt'] as String
          : defaultVoiceAnnouncementSummarySystemPrompt,
      realtimeAppId: j['realtimeAppId'] as String? ?? '',
      realtimeAppKey: j['realtimeAppKey'] as String? ?? '',
      realtimeAccessToken: j['realtimeAccessToken'] as String? ?? '',
      realtimeResourceId:
          (j['realtimeResourceId'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeResourceId'] as String
          : defaultVoiceAnnouncementRealtimeResourceId,
      realtimeModel: (j['realtimeModel'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeModel'] as String
          : defaultVoiceAnnouncementRealtimeModel,
      realtimeSpeaker:
          (j['realtimeSpeaker'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeSpeaker'] as String
          : defaultVoiceAnnouncementRealtimeSpeaker,
      realtimeSystemRole:
          (j['realtimeSystemRole'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeSystemRole'] as String
          : defaultVoiceAnnouncementRealtimeSystemRole,
      realtimeSpeakingStyle:
          (j['realtimeSpeakingStyle'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeSpeakingStyle'] as String
          : defaultVoiceAnnouncementRealtimeSpeakingStyle,
      realtimeSummaryPrompt:
          (j['realtimeSummaryPrompt'] as String?)?.trim().isNotEmpty == true
          ? j['realtimeSummaryPrompt'] as String
          : defaultVoiceAnnouncementRealtimeSummaryPrompt,
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

  bool get hasRealtimeDialogConfig =>
      realtimeAppId.trim().isNotEmpty &&
      realtimeAppKey.trim().isNotEmpty &&
      realtimeAccessToken.trim().isNotEmpty &&
      realtimeResourceId.trim().isNotEmpty;
}

enum DoubaoTtsPhase { loading, noStore, configured }
