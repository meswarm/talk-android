import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../keep_alive/keep_alive_controller.dart';
import '../theme/app_colors.dart';
import '../tts/doubao_tts_models.dart';
import '../tts/doubao_tts_service.dart';

class VoiceAnnouncementSettingsPage extends StatefulWidget {
  const VoiceAnnouncementSettingsPage({super.key});

  @override
  State<VoiceAnnouncementSettingsPage> createState() =>
      _VoiceAnnouncementSettingsPageState();
}

class _VoiceAnnouncementSettingsPageState
    extends State<VoiceAnnouncementSettingsPage> {
  final _apiKey = TextEditingController();
  final _resourceId = TextEditingController(text: 'seed-tts-2.0');
  final _speaker = TextEditingController();
  final _speechRate = TextEditingController(text: '0');
  final _loudnessRate = TextEditingController(text: '0');
  final _pitch = TextEditingController(text: '0');
  final _contextTexts = TextEditingController();
  final _qwenApiKey = TextEditingController();
  final _qwenModel = TextEditingController(
    text: defaultVoiceAnnouncementSummaryModel,
  );
  final _qwenSystemPrompt = TextEditingController(
    text: defaultVoiceAnnouncementSummarySystemPrompt,
  );
  final _realtimeAppId = TextEditingController();
  final _realtimeAppKey = TextEditingController();
  final _realtimeAccessToken = TextEditingController();
  final _realtimeResourceId = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeResourceId,
  );
  final _realtimeModel = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeModel,
  );
  final _realtimeSpeaker = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeSpeaker,
  );
  final _realtimeSystemRole = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeSystemRole,
  );
  final _realtimeSpeakingStyle = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeSpeakingStyle,
  );
  final _realtimeSummaryPrompt = TextEditingController(
    text: defaultVoiceAnnouncementRealtimeSummaryPrompt,
  );

  bool _enabled = false;
  bool _announceMessageContent = false;
  VoiceAnnouncementContentEngine _contentEngine =
      VoiceAnnouncementContentEngine.qwenTts;
  bool _markdownFilterEnabled = false;
  bool _latexEnabled = false;
  bool _filterParentheses = true;
  String _explicitDialect = '';
  bool _busy = false;
  String? _err;
  bool _didHydrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrate());
    });
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _resourceId.dispose();
    _speaker.dispose();
    _speechRate.dispose();
    _loudnessRate.dispose();
    _pitch.dispose();
    _contextTexts.dispose();
    _qwenApiKey.dispose();
    _qwenModel.dispose();
    _qwenSystemPrompt.dispose();
    _realtimeAppId.dispose();
    _realtimeAppKey.dispose();
    _realtimeAccessToken.dispose();
    _realtimeResourceId.dispose();
    _realtimeModel.dispose();
    _realtimeSpeaker.dispose();
    _realtimeSystemRole.dispose();
    _realtimeSpeakingStyle.dispose();
    _realtimeSummaryPrompt.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_didHydrate || !mounted) return;
    final tts = context.read<DoubaoTtsService>();
    var cfg = tts.config;
    if (cfg == null && tts.phase == DoubaoTtsPhase.loading) {
      await tts.bootstrap();
      cfg = tts.config;
    }
    if (!mounted) return;
    if (cfg != null) {
      _apiKey.text = cfg.apiKey;
      _resourceId.text = cfg.resourceId.trim().isEmpty
          ? 'seed-tts-2.0'
          : cfg.resourceId;
      _speaker.text = cfg.speaker;
      _speechRate.text = cfg.speechRate.toString();
      _loudnessRate.text = cfg.loudnessRate.toString();
      _pitch.text = cfg.pitch.toString();
      _contextTexts.text = cfg.contextTexts.join('\n');
      _announceMessageContent = cfg.announceMessageContent;
      _contentEngine = cfg.contentEngine;
      _qwenApiKey.text = cfg.qwenApiKey;
      _qwenModel.text = cfg.qwenModel;
      _qwenSystemPrompt.text = cfg.qwenSystemPrompt;
      _realtimeAppId.text = cfg.realtimeAppId;
      _realtimeAppKey.text = cfg.realtimeAppKey;
      _realtimeAccessToken.text = cfg.realtimeAccessToken;
      _realtimeResourceId.text = cfg.realtimeResourceId;
      _realtimeModel.text = cfg.realtimeModel;
      _realtimeSpeaker.text = cfg.realtimeSpeaker;
      _realtimeSystemRole.text = cfg.realtimeSystemRole;
      _realtimeSpeakingStyle.text = cfg.realtimeSpeakingStyle;
      _realtimeSummaryPrompt.text = cfg.realtimeSummaryPrompt;
      _markdownFilterEnabled = cfg.markdownFilterEnabled;
      _latexEnabled = cfg.latexEnabled;
      _filterParentheses = cfg.filterParentheses;
      _explicitDialect = cfg.explicitDialect;
      _enabled = cfg.enabled;
    }
    setState(() => _didHydrate = true);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final speechRate = _parseIntInRange(_speechRate.text, -50, 100, '语速');
    final loudnessRate = _parseIntInRange(_loudnessRate.text, -50, 100, '音量');
    final pitch = _parseIntInRange(_pitch.text, -12, 12, '音调');
    if (speechRate == null || loudnessRate == null || pitch == null) {
      setState(() => _busy = false);
      return;
    }
    if (_latexEnabled && !_markdownFilterEnabled) {
      setState(() {
        _err = '播报 LaTeX 公式需要同时开启 Markdown 解析过滤';
        _busy = false;
      });
      return;
    }
    if (_announceMessageContent &&
        _contentEngine == VoiceAnnouncementContentEngine.qwenTts &&
        _qwenApiKey.text.trim().isEmpty) {
      setState(() {
        _err = '开启播报消息内容时，请填写 Qwen API Key';
        _busy = false;
      });
      return;
    }
    if (_announceMessageContent &&
        _contentEngine == VoiceAnnouncementContentEngine.realtimeDialog &&
        (_realtimeAppId.text.trim().isEmpty ||
            _realtimeAppKey.text.trim().isEmpty ||
            _realtimeAccessToken.text.trim().isEmpty)) {
      setState(() {
        _err = '请填写实时语音 App ID、App Key 与 Access Token';
        _busy = false;
      });
      return;
    }
    final payload = DoubaoTtsConfig(
      enabled: _enabled,
      authMode: DoubaoTtsAuthMode.apiKey,
      apiKey: _apiKey.text.trim(),
      resourceId: _resourceId.text.trim().isEmpty
          ? 'seed-tts-2.0'
          : _resourceId.text.trim(),
      speaker: _speaker.text.trim(),
      speechRate: speechRate,
      loudnessRate: loudnessRate,
      markdownFilterEnabled: _markdownFilterEnabled,
      latexEnabled: _latexEnabled,
      filterParentheses: _filterParentheses,
      explicitDialect: _explicitDialect,
      pitch: pitch,
      contextTexts: _contextTextsFromController(),
      announceMessageContent: _announceMessageContent,
      contentEngine: _contentEngine,
      qwenApiKey: _qwenApiKey.text.trim(),
      qwenModel: _qwenModel.text.trim().isEmpty
          ? defaultVoiceAnnouncementSummaryModel
          : _qwenModel.text.trim(),
      qwenSystemPrompt: _qwenSystemPrompt.text.trim().isEmpty
          ? defaultVoiceAnnouncementSummarySystemPrompt
          : _qwenSystemPrompt.text.trim(),
      realtimeAppId: _realtimeAppId.text.trim(),
      realtimeAppKey: _realtimeAppKey.text.trim(),
      realtimeAccessToken: _realtimeAccessToken.text.trim(),
      realtimeResourceId: _realtimeResourceId.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeResourceId
          : _realtimeResourceId.text.trim(),
      realtimeModel: _realtimeModel.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeModel
          : _realtimeModel.text.trim(),
      realtimeSpeaker: _realtimeSpeaker.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSpeaker
          : _realtimeSpeaker.text.trim(),
      realtimeSystemRole: _realtimeSystemRole.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSystemRole
          : _realtimeSystemRole.text.trim(),
      realtimeSpeakingStyle: _realtimeSpeakingStyle.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSpeakingStyle
          : _realtimeSpeakingStyle.text.trim(),
      realtimeSummaryPrompt: _realtimeSummaryPrompt.text.trim().isEmpty
          ? defaultVoiceAnnouncementRealtimeSummaryPrompt
          : _realtimeSummaryPrompt.text.trim(),
    );
    if (!payload.isConfigured) {
      setState(() {
        _err = '请填写 API Key、Resource ID 与 Speaker';
        _busy = false;
      });
      return;
    }
    try {
      await context.read<DoubaoTtsService>().saveConfig(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('语音播报配置已保存'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除语音播报凭据'),
        content: const Text('将删除本机安全存储中的豆包配置，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<DoubaoTtsService>().clearConfig();
      if (!mounted) return;
      _enabled = false;
      _apiKey.clear();
      _resourceId.text = 'seed-tts-2.0';
      _speaker.clear();
      _speechRate.text = '0';
      _loudnessRate.text = '0';
      _pitch.text = '0';
      _contextTexts.clear();
      _announceMessageContent = false;
      _contentEngine = VoiceAnnouncementContentEngine.qwenTts;
      _qwenApiKey.clear();
      _qwenModel.text = defaultVoiceAnnouncementSummaryModel;
      _qwenSystemPrompt.text = defaultVoiceAnnouncementSummarySystemPrompt;
      _realtimeAppId.clear();
      _realtimeAppKey.clear();
      _realtimeAccessToken.clear();
      _realtimeResourceId.text = defaultVoiceAnnouncementRealtimeResourceId;
      _realtimeModel.text = defaultVoiceAnnouncementRealtimeModel;
      _realtimeSpeaker.text = defaultVoiceAnnouncementRealtimeSpeaker;
      _realtimeSystemRole.text = defaultVoiceAnnouncementRealtimeSystemRole;
      _realtimeSpeakingStyle.text =
          defaultVoiceAnnouncementRealtimeSpeakingStyle;
      _realtimeSummaryPrompt.text =
          defaultVoiceAnnouncementRealtimeSummaryPrompt;
      _markdownFilterEnabled = false;
      _latexEnabled = false;
      _filterParentheses = true;
      _explicitDialect = '';
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testAnnouncement() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<DoubaoTtsService>().speakTestPhrase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('测试播报完成'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setVoiceAnnouncementEnabled(bool enabled) async {
    final tts = context.read<DoubaoTtsService>();
    if (tts.config == null) {
      setState(() {
        _enabled = enabled;
        _err = null;
      });
      return;
    }
    if (tts.config?.isConfigured != true) {
      setState(() => _err = '请先保存可用的语音播报配置');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _enabled = enabled;
    });
    try {
      await tts.setEnabled(enabled);
    } catch (e) {
      if (!mounted) return;
      final current = tts.config?.enabled ?? false;
      setState(() {
        _enabled = current;
        _err = '$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int? _parseIntInRange(String raw, int min, int max, String label) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < min || value > max) {
      _err = '$label 取值范围为 $min 到 $max';
      return null;
    }
    return value;
  }

  List<String> _contextTextsFromController() {
    return _contextTexts.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final tts = context.watch<DoubaoTtsService>();
    final keepAlive = context.watch<KeepAliveController>();
    final ttsConfigured = tts.config?.isConfigured == true;

    return Scaffold(
      appBar: AppBar(title: const Text('语音播报')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '鉴权信息仅保存在本机系统安全存储，不会发往 Talk 服务器。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _enabled,
            onChanged: _busy
                ? null
                : (v) => unawaited(_setVoiceAnnouncementEnabled(v)),
            title: const Text('启用新消息语音播报'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _announceMessageContent,
            onChanged: _busy
                ? null
                : (v) => setState(() => _announceMessageContent = v),
            title: const Text('播报消息内容'),
            subtitle: const Text('开启后先用 Qwen 整理消息内容，再语音播报摘要。'),
            contentPadding: EdgeInsets.zero,
          ),
          if (_announceMessageContent) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<VoiceAnnouncementContentEngine>(
              key: ValueKey(_contentEngine),
              initialValue: _contentEngine,
              decoration: const InputDecoration(
                labelText: '消息整理方式',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: VoiceAnnouncementContentEngine.qwenTts,
                  child: Text('Qwen + 豆包 TTS'),
                ),
                DropdownMenuItem(
                  value: VoiceAnnouncementContentEngine.realtimeDialog,
                  child: Text('豆包实时语音大模型'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) => setState(
                      () => _contentEngine =
                          v ?? VoiceAnnouncementContentEngine.qwenTts,
                    ),
            ),
            const SizedBox(height: 12),
            if (_contentEngine == VoiceAnnouncementContentEngine.qwenTts) ...[
              TextField(
                controller: _qwenApiKey,
                decoration: const InputDecoration(
                  labelText: 'Qwen API Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qwenModel,
                decoration: const InputDecoration(
                  labelText: 'Qwen 模型',
                  helperText: defaultVoiceAnnouncementSummaryModel,
                  border: OutlineInputBorder(),
                ),
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qwenSystemPrompt,
                decoration: const InputDecoration(
                  labelText: '消息整理系统提示词',
                  border: OutlineInputBorder(),
                ),
                minLines: 4,
                maxLines: 6,
                enabled: !_busy,
                autocorrect: false,
              ),
            ] else ...[
              TextField(
                controller: _realtimeAppId,
                decoration: const InputDecoration(
                  labelText: '实时语音 App ID',
                  border: OutlineInputBorder(),
                ),
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeAppKey,
                decoration: const InputDecoration(
                  labelText: '实时语音 App Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeAccessToken,
                decoration: const InputDecoration(
                  labelText: '实时语音 Access Token',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeResourceId,
                decoration: const InputDecoration(
                  labelText: '实时语音 Resource ID',
                  helperText: defaultVoiceAnnouncementRealtimeResourceId,
                  border: OutlineInputBorder(),
                ),
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeModel,
                decoration: const InputDecoration(
                  labelText: '实时语音模型',
                  helperText: defaultVoiceAnnouncementRealtimeModel,
                  border: OutlineInputBorder(),
                ),
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeSpeaker,
                decoration: const InputDecoration(
                  labelText: '实时语音音色',
                  helperText: defaultVoiceAnnouncementRealtimeSpeaker,
                  border: OutlineInputBorder(),
                ),
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeSystemRole,
                decoration: const InputDecoration(
                  labelText: '实时语音系统提示词',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 5,
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeSpeakingStyle,
                decoration: const InputDecoration(
                  labelText: '实时语音说话风格',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                enabled: !_busy,
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _realtimeSummaryPrompt,
                decoration: const InputDecoration(
                  labelText: '实时语音播报整理指令',
                  border: OutlineInputBorder(),
                ),
                minLines: 4,
                maxLines: 6,
                enabled: !_busy,
                autocorrect: false,
              ),
            ],
          ],
          const Divider(height: 28),
          const Text(
            '常驻监听模式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            ttsConfigured
                ? '开启后 Android 会显示一个低优先级常驻通知，用于降低系统回收后漏播风险。'
                : '先保存可用的语音播报配置后才能开启。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          SwitchListTile(
            value: keepAlive.enabled,
            onChanged: !ttsConfigured || keepAlive.busy
                ? null
                : (v) => unawaited(keepAlive.setEnabled(v)),
            title: const Text('启用常驻监听模式'),
            subtitle: Text(keepAlive.running ? '常驻监听中' : '未开启常驻监听'),
            contentPadding: EdgeInsets.zero,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: keepAlive.busy
                  ? null
                  : () =>
                        unawaited(keepAlive.openBatteryOptimizationSettings()),
              child: const Text('电池优化设置'),
            ),
          ),
          if (keepAlive.error != null) ...[
            const SizedBox(height: 4),
            Text(
              keepAlive.error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const Divider(height: 28),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: '豆包 API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _resourceId,
            decoration: const InputDecoration(
              labelText: 'Resource ID',
              hintText: 'seed-tts-2.0',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speaker,
            decoration: const InputDecoration(
              labelText: 'Speaker',
              hintText: '例如: zh_female_shuangkuaisisi_moon_bigtts',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const Divider(height: 28),
          const Text(
            '合成参数',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speechRate,
            decoration: const InputDecoration(
              labelText: '语速',
              helperText: '范围 -50 到 100，0 为默认',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loudnessRate,
            decoration: const InputDecoration(
              labelText: '音量',
              helperText: '范围 -50 到 100，0 为默认',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _markdownFilterEnabled,
            onChanged: _busy
                ? null
                : (v) => setState(() => _markdownFilterEnabled = v),
            title: const Text('Markdown 解析过滤'),
            subtitle: const Text('开启后会过滤 Markdown 标记，例如 **你好** 读作“你好”。'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _latexEnabled,
            onChanged: _busy ? null : (v) => setState(() => _latexEnabled = v),
            title: const Text('播报 LaTeX 公式'),
            subtitle: const Text('需要同时开启 Markdown 解析过滤。'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _filterParentheses,
            onChanged: _busy
                ? null
                : (v) => setState(() => _filterParentheses = v),
            title: const Text('过滤括号内的部分'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_explicitDialect),
            initialValue: _explicitDialect,
            decoration: const InputDecoration(
              labelText: '明确方言',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('不指定')),
              DropdownMenuItem(value: 'dongbei', child: Text('东北话')),
              DropdownMenuItem(value: 'shaanxi', child: Text('陕西话')),
              DropdownMenuItem(value: 'sichuan', child: Text('四川话')),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() => _explicitDialect = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pitch,
            decoration: const InputDecoration(
              labelText: '音调取值',
              helperText: '范围 -12 到 12，0 为默认',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contextTexts,
            decoration: const InputDecoration(
              labelText: '语音合成辅助信息',
              helperText: '一行一条，例如：你可以说慢一点吗？',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
            enabled: !_busy,
            autocorrect: false,
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _testAnnouncement,
            child: const Text('测试播报'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _clear,
            child: const Text('清除本机配置'),
          ),
        ],
      ),
    );
  }
}
