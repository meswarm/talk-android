import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'doubao_tts_config_store.dart';
import 'doubao_tts_models.dart';
import 'realtime_voice_announcement_bridge.dart';

const _doubaoTtsEndpoint =
    'https://openspeech.bytedance.com/api/v3/tts/unidirectional';
const _qwenChatCompletionsEndpoint =
    'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

typedef DoubaoAudioPlayer = Future<void> Function(Uint8List bytes);
typedef RealtimeAnnouncementPlayer =
    Future<void> Function(DoubaoTtsConfig config, String text);

class DoubaoTtsService extends ChangeNotifier {
  DoubaoTtsService({
    DoubaoTtsConfigStore? store,
    http.Client? httpClient,
    AudioPlayer? player,
    DoubaoAudioPlayer? customAudioPlayer,
    RealtimeAnnouncementPlayer? realtimeAnnouncementPlayer,
    RealtimeVoiceAnnouncementBridge? realtimeBridge,
    Future<void> Function()? disableRealtimeSecretary,
  }) : _store = store ?? SecureDoubaoTtsConfigStore(),
       _httpClient = httpClient ?? http.Client(),
       _player = player,
       _customAudioPlayer = customAudioPlayer,
       _realtimeAnnouncementPlayer =
           realtimeAnnouncementPlayer ??
           ((config, text) {
             final bridge =
                 realtimeBridge ??
                 const MethodChannelRealtimeVoiceAnnouncementBridge();
             return bridge.speakTextQuery(config: config, text: text);
           }),
       _disableRealtimeSecretary = disableRealtimeSecretary;

  final DoubaoTtsConfigStore _store;
  final http.Client _httpClient;
  AudioPlayer? _player;
  final DoubaoAudioPlayer? _customAudioPlayer;
  final RealtimeAnnouncementPlayer _realtimeAnnouncementPlayer;
  final Future<void> Function()? _disableRealtimeSecretary;

  DoubaoTtsPhase _phase = DoubaoTtsPhase.loading;
  DoubaoTtsConfig? _config;
  Future<void> _announcementChain = Future<void>.value();

  DoubaoTtsPhase get phase => _phase;
  DoubaoTtsConfig? get config => _config;

  bool get enabled => _config?.enabled ?? false;
  bool get isConfigured => _config?.isConfigured ?? false;

  Future<void> bootstrap() async {
    _phase = DoubaoTtsPhase.loading;
    notifyListeners();
    try {
      final loaded = await _store.load();
      _config = loaded;
      _phase = loaded == null
          ? DoubaoTtsPhase.noStore
          : DoubaoTtsPhase.configured;
    } catch (_) {
      _config = null;
      _phase = DoubaoTtsPhase.noStore;
    }
    notifyListeners();
  }

  Future<void> saveConfig(DoubaoTtsConfig config) async {
    if (config.enabled) {
      await _disableRealtimeSecretary?.call();
    }
    final normalized = DoubaoTtsConfig(
      enabled: config.enabled,
      authMode: config.authMode,
      apiKey: config.apiKey.trim(),
      appId: config.appId.trim(),
      accessKey: config.accessKey.trim(),
      resourceId: config.resourceId.trim(),
      speaker: config.speaker.trim(),
      speechRate: config.speechRate.clamp(-50, 100),
      loudnessRate: config.loudnessRate.clamp(-50, 100),
      markdownFilterEnabled: config.markdownFilterEnabled,
      latexEnabled: config.latexEnabled,
      filterParentheses: config.filterParentheses,
      explicitDialect: config.explicitDialect.trim(),
      pitch: config.pitch.clamp(-12, 12),
      contextTexts: config.contextTexts
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false),
      announceMessageContent: config.announceMessageContent,
      contentEngine: config.contentEngine,
      qwenApiKey: config.qwenApiKey.trim(),
      qwenModel: config.qwenModel.trim().isEmpty
          ? defaultVoiceAnnouncementSummaryModel
          : config.qwenModel.trim(),
      qwenSystemPrompt: config.qwenSystemPrompt.trim().isEmpty
          ? defaultVoiceAnnouncementSummarySystemPrompt
          : config.qwenSystemPrompt.trim(),
      realtimeAppId: config.realtimeAppId.trim(),
      realtimeAppKey: config.realtimeAppKey.trim(),
      realtimeAccessToken: config.realtimeAccessToken.trim(),
      realtimeResourceId: config.realtimeResourceId.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeResourceId
          : config.realtimeResourceId.trim(),
      realtimeModel: config.realtimeModel.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeModel
          : config.realtimeModel.trim(),
      realtimeSpeaker: config.realtimeSpeaker.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSpeaker
          : config.realtimeSpeaker.trim(),
      realtimeSystemRole: config.realtimeSystemRole.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSystemRole
          : config.realtimeSystemRole.trim(),
      realtimeSpeakingStyle: config.realtimeSpeakingStyle.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSpeakingStyle
          : config.realtimeSpeakingStyle.trim(),
      realtimeSummaryPrompt: config.realtimeSummaryPrompt.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSummaryPrompt
          : config.realtimeSummaryPrompt.trim(),
    );
    await _store.save(normalized);
    _config = normalized;
    _phase = DoubaoTtsPhase.configured;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    final current = _config;
    if (current == null) {
      throw StateError('请先保存 API Key、Resource ID 与 Speaker');
    }
    await saveConfig(current.copyWith(enabled: enabled));
  }

  Future<void> clearConfig() async {
    await _store.clear();
    _config = null;
    _phase = DoubaoTtsPhase.noStore;
    notifyListeners();
  }

  String buildNewMessageAnnouncement(String senderName, {String? summary}) {
    final s = senderName.trim().isEmpty ? '未知联系人' : senderName.trim();
    final cleanSummary = summary?.trim();
    if (cleanSummary != null && cleanSummary.isNotEmpty) {
      return '$s 发来消息：$cleanSummary';
    }
    return '你有一条来自$s的新消息';
  }

  Future<void> enqueueNewMessageAnnouncement({
    required String senderName,
    String roomName = '',
    String messageBody = '',
  }) async {
    _announcementChain = _announcementChain
        .then(
          (_) => _speakNewMessageIfEnabled(
            senderName: senderName,
            roomName: roomName,
            messageBody: messageBody,
          ),
        )
        .catchError((_) {});
    return _announcementChain;
  }

  Future<void> speakTestPhrase() {
    return speakNow('语音播报已开启');
  }

  Future<void> speakNow(String text) async {
    final cfg = _requireConfig();
    final audioBytes = await _synthesizeToMp3(text: text.trim(), config: cfg);
    await _playAudio(audioBytes);
  }

  Future<void> _speakIfEnabled(String text) async {
    final cfg = _config;
    if (cfg == null || !cfg.enabled || !cfg.isConfigured) return;
    try {
      final audioBytes = await _synthesizeToMp3(text: text.trim(), config: cfg);
      await _playAudio(audioBytes);
    } catch (_) {
      // 语音播报失败不应影响消息通知流程。
    }
  }

  Future<void> _speakNewMessageIfEnabled({
    required String senderName,
    required String roomName,
    required String messageBody,
  }) async {
    final cfg = _config;
    if (cfg == null || !cfg.enabled || !cfg.isConfigured) return;
    var announcement = buildNewMessageAnnouncement(senderName);
    if (cfg.announceMessageContent && messageBody.trim().isNotEmpty) {
      if (cfg.contentEngine == VoiceAnnouncementContentEngine.realtimeDialog &&
          cfg.hasRealtimeDialogConfig) {
        try {
          await _realtimeAnnouncementPlayer(
            cfg,
            buildRealtimeAnnouncementPrompt(
              senderName: senderName,
              roomName: roomName,
              messageBody: messageBody,
              summaryPrompt: cfg.realtimeSummaryPrompt,
            ),
          );
          return;
        } catch (_) {
          // 实时语音大模型失败时继续走 Qwen + TTS 或普通提醒兜底。
        }
      }
      final summary = await _trySummarizeMessageForAnnouncement(
        senderName: senderName,
        roomName: roomName,
        messageBody: messageBody,
        config: cfg,
      );
      if (summary != null && summary.isNotEmpty) {
        announcement = buildNewMessageAnnouncement(
          senderName,
          summary: summary,
        );
      }
    }
    await _speakIfEnabled(announcement);
  }

  Future<String?> _trySummarizeMessageForAnnouncement({
    required String senderName,
    required String roomName,
    required String messageBody,
    required DoubaoTtsConfig config,
  }) async {
    if (config.qwenApiKey.trim().isEmpty || messageBody.trim().isEmpty) {
      return null;
    }
    try {
      return await summarizeMessageForAnnouncement(
        senderName: senderName,
        roomName: roomName,
        messageBody: messageBody,
        config: config,
      );
    } catch (_) {
      return null;
    }
  }

  String buildRealtimeAnnouncementPrompt({
    required String senderName,
    required String roomName,
    required String messageBody,
    String summaryPrompt = defaultVoiceAnnouncementRealtimeSummaryPrompt,
  }) {
    final sender = senderName.trim().isEmpty ? '未知联系人' : senderName.trim();
    return [
      summaryPrompt.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSummaryPrompt
          : summaryPrompt.trim(),
      if (roomName.trim().isNotEmpty) '房间：${roomName.trim()}',
      '发送者：$sender',
      '消息内容：',
      messageBody.trim(),
    ].join('\n');
  }

  Future<String> summarizeMessageForAnnouncement({
    required String senderName,
    required String roomName,
    required String messageBody,
    DoubaoTtsConfig? config,
  }) async {
    final cfg = config ?? _requireConfig();
    if (cfg.qwenApiKey.trim().isEmpty) {
      throw StateError('请先填写 Qwen API Key');
    }
    final request = http.Request(
      'POST',
      Uri.parse(_qwenChatCompletionsEndpoint),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${cfg.qwenApiKey.trim()}',
    });
    request.body = jsonEncode({
      'model': cfg.qwenModel.trim().isEmpty
          ? defaultVoiceAnnouncementSummaryModel
          : cfg.qwenModel.trim(),
      'messages': [
        {'role': 'system', 'content': cfg.qwenSystemPrompt.trim()},
        {
          'role': 'user',
          'content': [
            if (roomName.trim().isNotEmpty) '房间：${roomName.trim()}',
            '发送者：${senderName.trim().isEmpty ? '未知联系人' : senderName.trim()}',
            '消息内容：',
            messageBody.trim(),
          ].join('\n'),
        },
      ],
      'temperature': 0.2,
    });

    final streamed = await _httpClient.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError('Qwen 消息整理失败: ${streamed.statusCode} $body');
    }
    final decoded = jsonDecode(body);
    final choices = decoded is Map ? decoded['choices'] : null;
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    final summary = content?.toString().trim() ?? '';
    if (summary.isEmpty) {
      throw StateError('Qwen 消息整理未返回文本');
    }
    return _normalizeAnnouncementSummary(
      summary,
      senderName: senderName,
      roomName: roomName,
    );
  }

  static String _normalizeAnnouncementSummary(
    String raw, {
    String senderName = '',
    String roomName = '',
  }) {
    var collapsed = raw
        .replaceAll(RegExp(r'[#*_`>\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    collapsed = _stripDuplicatedNotificationPrefix(
      collapsed,
      senderName: senderName,
      roomName: roomName,
    );
    if (collapsed.length <= 120) return collapsed;
    return '${collapsed.substring(0, 120)}。';
  }

  static String _stripDuplicatedNotificationPrefix(
    String text, {
    required String senderName,
    required String roomName,
  }) {
    var current = text.trim();
    final names =
        {senderName.trim(), roomName.trim()}.where((s) => s.isNotEmpty).toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    for (var i = 0; i < 3; i += 1) {
      final before = current;
      for (final name in names) {
        final escaped = RegExp.escape(name);
        current = _stripPrefixIfLeavesContent(
          current,
          RegExp(
            '^$escaped\\s*(?:发来|来了|发送了|发了)?\\s*(?:一条)?\\s*(?:新)?消息\\s*[:：,，。\\-—]*\\s*',
          ),
        );
        current = _stripPrefixIfLeavesContent(
          current,
          RegExp(
            '^来自\\s*$escaped\\s*的?\\s*(?:一条)?\\s*(?:新)?消息\\s*[:：,，。\\-—]*\\s*',
          ),
        );
        current = _stripPrefixIfLeavesContent(
          current,
          RegExp('^$escaped\\s*[:：,，。\\-—]+\\s*'),
        );
      }
      current = _stripPrefixIfLeavesContent(
        current,
        RegExp('^(?:一条)?\\s*(?:新)?消息\\s*[:：,，。\\-—]+\\s*'),
      );
      if (current == before) break;
    }
    return current.trim();
  }

  static String _stripPrefixIfLeavesContent(String text, RegExp prefix) {
    final next = text.replaceFirst(prefix, '').trim();
    return next.isEmpty ? text : next;
  }

  DoubaoTtsConfig _requireConfig() {
    final cfg = _config;
    if (cfg == null || !cfg.isConfigured) {
      throw StateError('请先完整填写鉴权信息、Resource ID 与 Speaker');
    }
    return cfg;
  }

  Future<Uint8List> _synthesizeToMp3({
    required String text,
    required DoubaoTtsConfig config,
  }) async {
    if (text.isEmpty) {
      throw StateError('播报文本不能为空');
    }
    final request = http.Request('POST', Uri.parse(_doubaoTtsEndpoint));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'X-Api-Resource-Id': config.resourceId,
      'X-Api-Request-Id': _requestId(),
    });
    switch (config.authMode) {
      case DoubaoTtsAuthMode.apiKey:
        request.headers['X-Api-Key'] = config.apiKey;
      case DoubaoTtsAuthMode.appToken:
        request.headers['X-Api-App-Id'] = config.appId;
        request.headers['X-Api-Access-Key'] = config.accessKey;
    }
    final reqParams = <String, dynamic>{
      'text': text,
      'speaker': config.speaker,
      'audio_params': {
        'format': 'mp3',
        'sample_rate': 24000,
        'speech_rate': config.speechRate,
        'loudness_rate': config.loudnessRate,
      },
    };
    final additions = _buildAdditions(config);
    if (additions.isNotEmpty) {
      reqParams['additions'] = jsonEncode(additions);
    }
    request.body = jsonEncode({
      'user': {'uid': 'talk-mobile'},
      'req_params': reqParams,
    });

    final streamed = await _httpClient.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final errBody = await streamed.stream.bytesToString();
      final logId = streamed.headers['x-tt-logid'];
      final suffix = [
        if (logId != null && logId.isNotEmpty) 'logid=$logId',
        if (errBody.trim().isNotEmpty) errBody.trim(),
      ].join(' ');
      throw StateError(
        '语音合成请求失败: ${streamed.statusCode}'
        '${suffix.isEmpty ? '' : ' $suffix'}',
      );
    }

    final audioBuilder = BytesBuilder(copy: false);
    final extractor = _JsonObjectExtractor();
    final nonAudioEvents = <String>[];
    await for (final piece in streamed.stream.transform(utf8.decoder)) {
      final objs = extractor.add(piece);
      for (final obj in objs) {
        final code = obj['code'];
        final data = obj['data'];
        if (code == 0 && data is String && data.isNotEmpty) {
          audioBuilder.add(base64Decode(data));
          continue;
        }
        if (code == 20000000) {
          // 结束事件，继续等待流自然结束即可。
          continue;
        }
        if (code != null || obj['message'] != null) {
          nonAudioEvents.add(jsonEncode(obj));
        }
      }
    }

    final bytes = audioBuilder.takeBytes();
    if (bytes.isEmpty) {
      final detail = nonAudioEvents.isEmpty
          ? ''
          : '，原始响应摘要: ${nonAudioEvents.take(3).join(' ')}';
      throw StateError('语音合成未返回音频数据$detail');
    }
    return bytes;
  }

  Future<void> _playAudio(Uint8List bytes) async {
    if (_customAudioPlayer != null) {
      await _customAudioPlayer(bytes);
      return;
    }
    final player = _player ??= AudioPlayer();
    final done = Completer<void>();
    late final StreamSubscription<void> sub;
    sub = player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await player.stop();
      await player.play(BytesSource(bytes));
      await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    } finally {
      await sub.cancel();
    }
  }

  static String _requestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    return 'talk-$now-${rand.toRadixString(16)}';
  }

  static Map<String, dynamic> _buildAdditions(DoubaoTtsConfig config) {
    final additions = <String, dynamic>{};
    if (config.markdownFilterEnabled || config.latexEnabled) {
      additions['disable_markdown_filter'] = true;
    }
    if (config.latexEnabled) {
      additions['enable_latex_tn'] = true;
      additions['latex_parser'] = 'v2';
    }
    if (!config.filterParentheses) {
      additions['max_length_to_filter_parenthesis'] = 0;
    }
    if (config.explicitDialect.trim().isNotEmpty) {
      additions['explicit_dialect'] = config.explicitDialect.trim();
    }
    if (config.pitch != 0) {
      additions['post_process'] = {'pitch': config.pitch};
    }
    if (config.contextTexts.isNotEmpty) {
      additions['context_texts'] = config.contextTexts;
    }
    return additions;
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      unawaited(player.dispose());
    }
    _httpClient.close();
    super.dispose();
  }
}

class _JsonObjectExtractor {
  var _buffer = StringBuffer();
  var _depth = 0;
  var _started = false;
  var _inString = false;
  var _escaped = false;

  Iterable<Map<String, dynamic>> add(String chunk) {
    final out = <Map<String, dynamic>>[];
    for (final rune in chunk.runes) {
      final ch = String.fromCharCode(rune);
      if (!_started) {
        if (ch == '{') {
          _started = true;
          _depth = 1;
          _inString = false;
          _escaped = false;
          _buffer.write(ch);
        }
        continue;
      }
      _buffer.write(ch);
      if (_inString) {
        if (_escaped) {
          _escaped = false;
          continue;
        }
        if (ch == r'\') {
          _escaped = true;
          continue;
        }
        if (ch == '"') {
          _inString = false;
        }
        continue;
      }
      if (ch == '"') {
        _inString = true;
        continue;
      }
      if (ch == '{') {
        _depth += 1;
        continue;
      }
      if (ch != '}') continue;
      _depth -= 1;
      if (_depth != 0) continue;
      final raw = _buffer.toString();
      _buffer = StringBuffer();
      _started = false;
      _inString = false;
      _escaped = false;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          out.add(decoded);
        }
      } catch (_) {
        // 忽略无法解析的片段，继续提取后续对象。
      }
    }
    return out;
  }
}
