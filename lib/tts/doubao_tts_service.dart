import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'doubao_tts_config_store.dart';
import 'doubao_tts_models.dart';

const _doubaoTtsEndpoint =
    'https://openspeech.bytedance.com/api/v3/tts/unidirectional';

typedef DoubaoAudioPlayer = Future<void> Function(Uint8List bytes);

class DoubaoTtsService extends ChangeNotifier {
  DoubaoTtsService({
    DoubaoTtsConfigStore? store,
    http.Client? httpClient,
    AudioPlayer? player,
    DoubaoAudioPlayer? customAudioPlayer,
  }) : _store = store ?? SecureDoubaoTtsConfigStore(),
       _httpClient = httpClient ?? http.Client(),
       _player = player,
       _customAudioPlayer = customAudioPlayer;

  final DoubaoTtsConfigStore _store;
  final http.Client _httpClient;
  AudioPlayer? _player;
  final DoubaoAudioPlayer? _customAudioPlayer;

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

  String buildNewMessageAnnouncement(String senderName) {
    final s = senderName.trim().isEmpty ? '未知联系人' : senderName.trim();
    return '你有一条来自$s的新消息';
  }

  Future<void> enqueueNewMessageAnnouncement({
    required String senderName,
  }) async {
    _announcementChain = _announcementChain
        .then((_) => _speakIfEnabled(buildNewMessageAnnouncement(senderName)))
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
