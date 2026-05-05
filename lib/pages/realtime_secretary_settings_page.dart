import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../realtime_secretary/realtime_secretary_models.dart';
import '../realtime_secretary/realtime_secretary_service.dart';
import '../theme/app_colors.dart';
import '../tts/doubao_tts_service.dart';

class RealtimeSecretarySettingsPage extends StatefulWidget {
  const RealtimeSecretarySettingsPage({super.key});

  @override
  State<RealtimeSecretarySettingsPage> createState() =>
      _RealtimeSecretarySettingsPageState();
}

class _RealtimeSecretarySettingsPageState
    extends State<RealtimeSecretarySettingsPage> {
  final _appId = TextEditingController();
  final _appKey = TextEditingController();
  final _accessToken = TextEditingController();
  final _resourceId = TextEditingController(
    text: defaultRealtimeSecretaryResourceId,
  );
  final _secretaryName = TextEditingController(
    text: defaultRealtimeSecretaryName,
  );
  final _systemRole = TextEditingController();
  final _speakingStyle = TextEditingController();
  final _model = TextEditingController(text: defaultRealtimeSecretaryModel);
  final _speaker = TextEditingController(text: defaultRealtimeSecretarySpeaker);
  final _speechRate = TextEditingController(
    text: '$defaultRealtimeSecretarySpeechRate',
  );
  final _loudnessRate = TextEditingController(
    text: '$defaultRealtimeSecretaryLoudnessRate',
  );
  final _wakeWaitSeconds = TextEditingController(
    text: '$defaultRealtimeSecretaryWakeWaitSeconds',
  );
  final _activeChatIdleSeconds = TextEditingController(
    text: '$defaultRealtimeSecretaryActiveChatIdleSeconds',
  );
  final _contextMessageCount = TextEditingController(
    text: '$defaultRealtimeSecretaryContextMessageCount',
  );

  bool _enabled = false;
  bool _requireWakePhrase = true;
  bool _busy = false;
  bool _didHydrate = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrate());
    });
  }

  @override
  void dispose() {
    _appId.dispose();
    _appKey.dispose();
    _accessToken.dispose();
    _resourceId.dispose();
    _secretaryName.dispose();
    _systemRole.dispose();
    _speakingStyle.dispose();
    _model.dispose();
    _speaker.dispose();
    _speechRate.dispose();
    _loudnessRate.dispose();
    _wakeWaitSeconds.dispose();
    _activeChatIdleSeconds.dispose();
    _contextMessageCount.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_didHydrate || !mounted) return;
    final service = context.read<RealtimeSecretaryService>();
    var cfg = service.config;
    if (cfg == null) {
      await service.bootstrap();
      cfg = service.config;
    }
    if (!mounted) return;
    if (cfg != null) {
      _enabled = cfg.enabled;
      _requireWakePhrase = cfg.requireWakePhrase;
      _appId.text = cfg.appId;
      _appKey.text = cfg.appKey;
      _accessToken.text = cfg.accessToken;
      _resourceId.text = cfg.resourceId;
      _secretaryName.text = cfg.secretaryName;
      _systemRole.text = cfg.systemRole;
      _speakingStyle.text = cfg.speakingStyle;
      _model.text = cfg.model;
      _speaker.text = cfg.speaker;
      _speechRate.text = '${cfg.speechRate}';
      _loudnessRate.text = '${cfg.loudnessRate}';
      _wakeWaitSeconds.text = '${cfg.wakeWaitSeconds}';
      _activeChatIdleSeconds.text = '${cfg.activeChatIdleSeconds}';
      _contextMessageCount.text = '${cfg.contextMessageCount}';
    }
    setState(() => _didHydrate = true);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final payload = _formConfig();
    if (payload.enabled && !payload.isConfigured) {
      setState(() {
        _err = '请填写 App ID、App Key、Access Token 与 Resource ID';
        _busy = false;
      });
      return;
    }

    try {
      final secretary = context.read<RealtimeSecretaryService>();
      if (payload.enabled) {
        final tts = context.read<DoubaoTtsService>();
        if (tts.config != null) {
          await tts.setEnabled(false);
        }
      }
      await secretary.saveConfig(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('实时语音秘书配置已保存'),
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

  Future<void> _testConfig() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final payload = _formConfig();
    if (!payload.isConfigured) {
      setState(() {
        _err = '请填写 App ID、App Key、Access Token 与 Resource ID';
        _busy = false;
      });
      return;
    }

    try {
      await context.read<RealtimeSecretaryService>().testConfig(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('测试已启动，如果配置正确会听到测试提示音'),
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

  RealtimeSecretaryConfig _formConfig() {
    final wait = _parseInt(
      _wakeWaitSeconds.text,
      defaultRealtimeSecretaryWakeWaitSeconds,
      minRealtimeSecretaryWakeWaitSeconds,
      maxRealtimeSecretaryWakeWaitSeconds,
    );
    final contextCount = _parseInt(
      _contextMessageCount.text,
      defaultRealtimeSecretaryContextMessageCount,
      minRealtimeSecretaryContextMessageCount,
      maxRealtimeSecretaryContextMessageCount,
    );
    final activeChatIdleSeconds = _parseInt(
      _activeChatIdleSeconds.text,
      defaultRealtimeSecretaryActiveChatIdleSeconds,
      minRealtimeSecretaryActiveChatIdleSeconds,
      maxRealtimeSecretaryActiveChatIdleSeconds,
    );
    final speechRate = _parseInt(
      _speechRate.text,
      defaultRealtimeSecretarySpeechRate,
      minRealtimeSecretarySpeechRate,
      maxRealtimeSecretarySpeechRate,
    );
    final loudnessRate = _parseInt(
      _loudnessRate.text,
      defaultRealtimeSecretaryLoudnessRate,
      minRealtimeSecretaryLoudnessRate,
      maxRealtimeSecretaryLoudnessRate,
    );
    return RealtimeSecretaryConfig(
      enabled: _enabled,
      appId: _appId.text.trim(),
      appKey: _appKey.text.trim(),
      accessToken: _accessToken.text.trim(),
      resourceId: _resourceId.text.trim().isEmpty
          ? defaultRealtimeSecretaryResourceId
          : _resourceId.text.trim(),
      secretaryName: _secretaryName.text.trim().isEmpty
          ? defaultRealtimeSecretaryName
          : _secretaryName.text.trim(),
      requireWakePhrase: _requireWakePhrase,
      systemRole: _systemRole.text.trim(),
      speakingStyle: _speakingStyle.text.trim(),
      model: _model.text.trim().isEmpty
          ? defaultRealtimeSecretaryModel
          : _model.text.trim(),
      speaker: _speaker.text.trim().isEmpty
          ? defaultRealtimeSecretarySpeaker
          : _speaker.text.trim(),
      speechRate: speechRate,
      loudnessRate: loudnessRate,
      wakeWaitSeconds: wait,
      activeChatIdleSeconds: activeChatIdleSeconds,
      contextMessageCount: contextCount,
    );
  }

  Future<void> _clear() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<RealtimeSecretaryService>().clearConfig();
      if (!mounted) return;
      _enabled = false;
      _requireWakePhrase = true;
      _appId.clear();
      _appKey.clear();
      _accessToken.clear();
      _resourceId.text = defaultRealtimeSecretaryResourceId;
      _secretaryName.text = defaultRealtimeSecretaryName;
      _systemRole.clear();
      _speakingStyle.clear();
      _model.text = defaultRealtimeSecretaryModel;
      _speaker.text = defaultRealtimeSecretarySpeaker;
      _speechRate.text = '$defaultRealtimeSecretarySpeechRate';
      _loudnessRate.text = '$defaultRealtimeSecretaryLoudnessRate';
      _wakeWaitSeconds.text = '$defaultRealtimeSecretaryWakeWaitSeconds';
      _activeChatIdleSeconds.text =
          '$defaultRealtimeSecretaryActiveChatIdleSeconds';
      _contextMessageCount.text =
          '$defaultRealtimeSecretaryContextMessageCount';
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _parseInt(String raw, int fallback, int min, int max) {
    final value = int.tryParse(raw.trim()) ?? fallback;
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final service = context.watch<RealtimeSecretaryService>();

    return Scaffold(
      appBar: AppBar(title: const Text('实时语音秘书')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '暗号通过前只播报房间名，不会把消息正文交给模型。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
            title: const Text('启用实时语音秘书'),
            subtitle: Text(service.serviceRunning ? '秘书常驻服务运行中' : '秘书常驻服务未运行'),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 28),
          TextField(
            controller: _appId,
            decoration: const InputDecoration(
              labelText: 'App ID',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appKey,
            decoration: const InputDecoration(
              labelText: 'App Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accessToken,
            decoration: const InputDecoration(
              labelText: 'Access Token',
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
              hintText: defaultRealtimeSecretaryResourceId,
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const Divider(height: 28),
          TextField(
            controller: _secretaryName,
            decoration: const InputDecoration(
              labelText: '秘书名称',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _requireWakePhrase,
            onChanged: _busy
                ? null
                : (v) => setState(() => _requireWakePhrase = v),
            title: const Text('需要暗号确认'),
            subtitle: const Text('关闭后新消息会直接把上下文交给秘书并进入对话'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _systemRole,
            decoration: const InputDecoration(
              labelText: '系统角色',
              helperText: '可选，用于配置背景人设信息',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speakingStyle,
            decoration: const InputDecoration(
              labelText: '说话风格',
              helperText: '可选，用于配置模型对话风格',
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 4,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型版本',
              helperText: '默认 1.2.1.1；SC2.0 可填 2.2.0.0',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speaker,
            decoration: const InputDecoration(
              labelText: '说话人音色',
              helperText: defaultRealtimeSecretarySpeaker,
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _speechRate,
            decoration: const InputDecoration(
              labelText: '语速',
              helperText: '范围 -50 到 100，默认 0',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loudnessRate,
            decoration: const InputDecoration(
              labelText: '音量',
              helperText: '范围 -50 到 100，默认 0',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wakeWaitSeconds,
            decoration: const InputDecoration(
              labelText: '等待暗号时间（秒）',
              helperText: '范围 5 到 30 秒',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _activeChatIdleSeconds,
            decoration: const InputDecoration(
              labelText: '对话空闲超时（秒）',
              helperText: '范围 5 到 30 秒，默认 10 秒',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contextMessageCount,
            decoration: const InputDecoration(
              labelText: '最近聊天上下文条数',
              helperText: '范围 1 到 10 条',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            enabled: !_busy,
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
            onPressed: _busy ? null : _testConfig,
            child: const Text('测试配置'),
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
