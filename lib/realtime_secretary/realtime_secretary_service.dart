import 'dart:async';

import 'package:flutter/foundation.dart';

import 'realtime_secretary_config_store.dart';
import 'realtime_secretary_models.dart';
import 'realtime_secretary_service_bridge.dart';

export 'realtime_secretary_service_bridge.dart';

enum RealtimeSecretarySessionState {
  idle,
  announcing,
  waitingWake,
  activeChat,
  closing,
}

enum RealtimeSecretaryDebugSpeaker { secretary, user, system }

class RealtimeSecretaryDebugEntry {
  final RealtimeSecretaryDebugSpeaker speaker;
  final String text;

  const RealtimeSecretaryDebugEntry({
    required this.speaker,
    required this.text,
  });
}

typedef RealtimeSecretaryContextLoader =
    Future<List<SecretaryTextBubble>> Function();

class RealtimeSecretaryService extends ChangeNotifier {
  RealtimeSecretaryService({
    RealtimeSecretaryConfigStore? store,
    RealtimeSecretaryBridge? bridge,
    Future<void> Function()? disableVoiceAnnouncement,
  }) : _store = store ?? SecureRealtimeSecretaryConfigStore(),
       _bridge = bridge ?? MethodChannelRealtimeSecretaryBridge(),
       _disableVoiceAnnouncement = disableVoiceAnnouncement {
    final bridge = _bridge;
    if (bridge is MethodChannelRealtimeSecretaryBridge) {
      bridge.onRecognizedText = handleRecognizedText;
      bridge.onSessionEnded = handleNativeSessionEnded;
      bridge.onSpeechStarted = handleNativeSpeechStarted;
      bridge.onSpeechEnded = handleNativeSpeechEnded;
    }
  }

  final RealtimeSecretaryConfigStore _store;
  final RealtimeSecretaryBridge _bridge;
  final Future<void> Function()? _disableVoiceAnnouncement;

  RealtimeSecretaryConfig? _config;
  RealtimeSecretarySessionState _state = RealtimeSecretarySessionState.idle;
  RealtimeSecretaryContextLoader? _pendingContextLoader;
  SecretaryTextBubble? _triggerMessage;
  final List<RealtimeSecretaryDebugEntry> _debugConversationEntries = [];
  Timer? _wakeTimer;
  Timer? _activeChatIdleTimer;
  bool _serviceRunning = false;
  String? _error;

  RealtimeSecretaryConfig? get config => _config;
  RealtimeSecretarySessionState get state => _state;
  bool get enabled => _config?.enabled ?? false;
  bool get isConfigured => _config?.isConfigured ?? false;
  bool get serviceRunning => _serviceRunning;
  String? get error => _error;
  int get activeChatIdleSeconds =>
      _config?.activeChatIdleSeconds ??
      defaultRealtimeSecretaryActiveChatIdleSeconds;
  bool get shouldShowDebugConversation =>
      _state != RealtimeSecretarySessionState.idle;
  bool get isActiveChatIdleTimerRunning =>
      _activeChatIdleTimer?.isActive ?? false;
  List<RealtimeSecretaryDebugEntry> get debugConversationEntries =>
      List.unmodifiable(_debugConversationEntries);

  Future<void> bootstrap() async {
    try {
      _config = await _store.load();
      _serviceRunning = await _bridge.isServiceRunning();
      notifyListeners();
      if (_config?.enabled == true && !_serviceRunning) {
        await _bridge.startForegroundService(_config!);
        _serviceRunning = true;
        notifyListeners();
      }
    } catch (e) {
      _error = '$e';
      notifyListeners();
    }
  }

  Future<void> saveConfig(RealtimeSecretaryConfig config) async {
    final normalized = _normalize(config);
    if (normalized.enabled) {
      await _disableVoiceAnnouncement?.call();
    }
    await _store.save(normalized);
    _config = normalized;
    if (normalized.enabled) {
      await _bridge.startForegroundService(normalized);
      _serviceRunning = true;
    } else {
      await _bridge.stopForegroundService();
      _serviceRunning = false;
      await _closeSession();
    }
    _error = null;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    final current = _config;
    if (current == null || !current.isConfigured) {
      throw StateError('请先保存实时语音秘书鉴权信息');
    }
    await saveConfig(current.copyWith(enabled: enabled));
  }

  Future<void> testConfig(RealtimeSecretaryConfig config) async {
    final normalized = _normalize(config);
    if (!normalized.isConfigured) {
      throw StateError('请填写 App ID、App Key、Access Token 与 Resource ID');
    }
    await _bridge.startForegroundService(normalized);
    _serviceRunning = true;
    notifyListeners();
    await _bridge.testConfig(normalized);
  }

  Future<void> clearConfig() async {
    await _store.clear();
    _config = null;
    await _bridge.stopForegroundService();
    _serviceRunning = false;
    await _closeSession();
    notifyListeners();
  }

  String buildOpeningAnnouncement(String roomName) {
    final name = roomName.trim().isEmpty ? '某个房间' : roomName.trim();
    return '$name 来了消息。';
  }

  bool matchesWakePhrase(String text, {String? secretaryName}) {
    final name = (secretaryName ?? _config?.secretaryName ?? '').trim();
    return name.isNotEmpty && text.contains(name);
  }

  Future<bool> tryStartForNewTextMessage({
    required String roomId,
    required String roomName,
    SecretaryTextBubble? triggerMessage,
    required RealtimeSecretaryContextLoader contextLoader,
  }) async {
    final cfg = _config;
    if (cfg == null || !cfg.enabled || !cfg.isConfigured) return false;
    if (_state != RealtimeSecretarySessionState.idle) return false;

    _pendingContextLoader = contextLoader;
    _triggerMessage = triggerMessage;
    _debugConversationEntries.clear();
    final opening = buildOpeningAnnouncement(roomName);
    _addDebugConversationEntry(
      speaker: RealtimeSecretaryDebugSpeaker.secretary,
      text: opening,
      notify: false,
    );
    String? initialContextText;
    if (!cfg.requireWakePhrase) {
      initialContextText = await _buildPendingContextText(cfg);
    }
    _setState(RealtimeSecretarySessionState.announcing);
    await _bridge.startWakeSession(
      config: cfg,
      roomId: roomId,
      openingAnnouncement: opening,
      initialContextText: initialContextText,
    );
    if (!cfg.requireWakePhrase) {
      _addContextDebugEntries(
        cfg,
        contextText: initialContextText!,
        statusText: '已关闭暗号确认，已初始化最近 ${cfg.contextMessageCount} 条上下文。',
      );
      _setState(RealtimeSecretarySessionState.activeChat);
      _startActiveChatIdleTimer();
      return true;
    }
    _setState(RealtimeSecretarySessionState.waitingWake);
    _startWakeTimer(cfg.wakeWaitSeconds);
    return true;
  }

  Future<void> handleRecognizedText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _addDebugConversationEntry(
      speaker: RealtimeSecretaryDebugSpeaker.user,
      text: trimmed,
    );

    if (_state == RealtimeSecretarySessionState.waitingWake) {
      final cfg = _config;
      if (cfg == null || !matchesWakePhrase(trimmed)) return;
      _wakeTimer?.cancel();
      await _sendContextAndEnterActiveChat(
        cfg,
        statusText: '暗号通过，已发送最近 ${cfg.contextMessageCount} 条上下文。',
      );
      return;
    }

    if (_state == RealtimeSecretarySessionState.activeChat) {
      _startActiveChatIdleTimer();
      if (isClosingPhrase(trimmed)) {
        await _closeSession();
      }
    }
  }

  bool isClosingPhrase(String text) {
    final normalized = text.trim().toLowerCase();
    const phrases = [
      '好的',
      '好滴',
      '知道',
      '晓得',
      '不用管',
      '不用处理',
      '别管',
      '没事',
      '没问题',
      '结束',
      '可以了',
      '行了',
      'ok',
      'okay',
    ];
    return phrases.any(normalized.contains);
  }

  String buildContextPrompt(
    List<SecretaryTextBubble> bubbles, {
    required int maxCount,
  }) {
    final count = maxCount.clamp(
      minRealtimeSecretaryContextMessageCount,
      maxRealtimeSecretaryContextMessageCount,
    );
    final merged = _mergeTriggerMessage(bubbles);
    final recent = merged.length <= count
        ? merged
        : merged.sublist(merged.length - count);
    if (recent.isEmpty) {
      return '用户通过暗号确认查看消息，但最近没有可用的文本上下文。';
    }
    final lines = recent
        .map((b) => '${_senderName(b.senderName)}: ${b.body.trim()}')
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    return '以下是该房间最近 $count 条文本消息上下文，请基于这些内容继续和用户语音对话：\n$lines';
  }

  Future<void> _sendContextAndEnterActiveChat(
    RealtimeSecretaryConfig cfg, {
    required String statusText,
  }) async {
    final contextText = await _buildPendingContextText(cfg);
    await _bridge.sendContextTextQuery(contextText);
    _addContextDebugEntries(
      cfg,
      contextText: contextText,
      statusText: statusText,
    );
    _setState(RealtimeSecretarySessionState.activeChat);
    _startActiveChatIdleTimer();
  }

  Future<String> _buildPendingContextText(RealtimeSecretaryConfig cfg) async {
    final loader = _pendingContextLoader;
    final bubbles = loader == null
        ? const <SecretaryTextBubble>[]
        : await loader();
    return buildContextPrompt(bubbles, maxCount: cfg.contextMessageCount);
  }

  void _addContextDebugEntries(
    RealtimeSecretaryConfig cfg, {
    required String contextText,
    required String statusText,
  }) {
    _addDebugConversationEntry(
      speaker: RealtimeSecretaryDebugSpeaker.system,
      text: statusText,
      notify: false,
    );
    _addDebugConversationEntry(
      speaker: RealtimeSecretaryDebugSpeaker.system,
      text: '发送给秘书的上下文：\n$contextText',
      notify: false,
    );
  }

  void debugExpireWakeWait() {
    if (_state == RealtimeSecretarySessionState.waitingWake) {
      _wakeTimer?.cancel();
      _finishSessionLocally();
      unawaited(_bridge.stopSession());
    }
  }

  Future<void> debugExpireActiveChatIdle() async {
    if (_state == RealtimeSecretarySessionState.activeChat) {
      _activeChatIdleTimer?.cancel();
      await _closeSession();
    }
  }

  void handleNativeSessionEnded({String? reason}) {
    _finishSessionLocally();
  }

  void handleNativeSpeechStarted() {
    if (_state == RealtimeSecretarySessionState.activeChat) {
      _activeChatIdleTimer?.cancel();
    }
  }

  void handleNativeSpeechEnded() {
    if (_state == RealtimeSecretarySessionState.activeChat) {
      _startActiveChatIdleTimer();
    }
  }

  void _startWakeTimer(int seconds) {
    _wakeTimer?.cancel();
    _wakeTimer = Timer(Duration(seconds: seconds), () {
      if (_state == RealtimeSecretarySessionState.waitingWake) {
        unawaited(_closeSession());
      }
    });
  }

  void _startActiveChatIdleTimer() {
    _activeChatIdleTimer?.cancel();
    final seconds =
        _config?.activeChatIdleSeconds ??
        defaultRealtimeSecretaryActiveChatIdleSeconds;
    _activeChatIdleTimer = Timer(Duration(seconds: seconds), () {
      if (_state == RealtimeSecretarySessionState.activeChat) {
        unawaited(_closeSession());
      }
    });
  }

  Future<void> _closeSession() async {
    _wakeTimer?.cancel();
    _activeChatIdleTimer?.cancel();
    if (_state == RealtimeSecretarySessionState.idle) return;
    _setState(RealtimeSecretarySessionState.closing);
    await _bridge.stopSession();
    _finishSessionLocally();
  }

  void _finishSessionLocally() {
    _wakeTimer?.cancel();
    _activeChatIdleTimer?.cancel();
    _pendingContextLoader = null;
    _triggerMessage = null;
    if (_state == RealtimeSecretarySessionState.idle) return;
    _addDebugConversationEntry(
      speaker: RealtimeSecretaryDebugSpeaker.system,
      text: '会话结束。',
      notify: false,
    );
    _setState(RealtimeSecretarySessionState.idle);
  }

  void _setState(RealtimeSecretarySessionState next) {
    _state = next;
    notifyListeners();
  }

  void _addDebugConversationEntry({
    required RealtimeSecretaryDebugSpeaker speaker,
    required String text,
    bool notify = true,
  }) {
    _debugConversationEntries.add(
      RealtimeSecretaryDebugEntry(speaker: speaker, text: text),
    );
    if (_debugConversationEntries.length > 30) {
      _debugConversationEntries.removeRange(
        0,
        _debugConversationEntries.length - 30,
      );
    }
    if (notify) notifyListeners();
  }

  List<SecretaryTextBubble> _mergeTriggerMessage(
    List<SecretaryTextBubble> bubbles,
  ) {
    final trigger = _triggerMessage;
    if (trigger == null || trigger.body.trim().isEmpty) {
      return List<SecretaryTextBubble>.from(bubbles);
    }
    final merged = List<SecretaryTextBubble>.from(bubbles);
    final alreadyIncluded = merged.any(
      (bubble) =>
          bubble.senderName == trigger.senderName &&
          bubble.body == trigger.body,
    );
    if (!alreadyIncluded) merged.add(trigger);
    return merged;
  }

  static String _senderName(String raw) {
    return raw.trim().isEmpty ? '未知' : raw.trim();
  }

  static RealtimeSecretaryConfig _normalize(RealtimeSecretaryConfig config) {
    return RealtimeSecretaryConfig(
      enabled: config.enabled,
      appId: config.appId.trim(),
      appKey: config.appKey.trim(),
      accessToken: config.accessToken.trim(),
      resourceId: config.resourceId.trim().isEmpty
          ? defaultRealtimeSecretaryResourceId
          : config.resourceId.trim(),
      secretaryName: config.secretaryName.trim().isEmpty
          ? defaultRealtimeSecretaryName
          : config.secretaryName.trim(),
      requireWakePhrase: config.requireWakePhrase,
      systemRole: config.systemRole.trim(),
      speakingStyle: config.speakingStyle.trim(),
      model: config.model.trim().isEmpty
          ? defaultRealtimeSecretaryModel
          : config.model.trim(),
      speaker: config.speaker.trim().isEmpty
          ? defaultRealtimeSecretarySpeaker
          : config.speaker.trim(),
      speechRate: config.speechRate.clamp(
        minRealtimeSecretarySpeechRate,
        maxRealtimeSecretarySpeechRate,
      ),
      loudnessRate: config.loudnessRate.clamp(
        minRealtimeSecretaryLoudnessRate,
        maxRealtimeSecretaryLoudnessRate,
      ),
      wakeWaitSeconds: config.wakeWaitSeconds.clamp(
        minRealtimeSecretaryWakeWaitSeconds,
        maxRealtimeSecretaryWakeWaitSeconds,
      ),
      activeChatIdleSeconds: config.activeChatIdleSeconds.clamp(
        minRealtimeSecretaryActiveChatIdleSeconds,
        maxRealtimeSecretaryActiveChatIdleSeconds,
      ),
      contextMessageCount: config.contextMessageCount.clamp(
        minRealtimeSecretaryContextMessageCount,
        maxRealtimeSecretaryContextMessageCount,
      ),
    );
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    _activeChatIdleTimer?.cancel();
    super.dispose();
  }
}
