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
  final _appId = TextEditingController();
  final _accessKey = TextEditingController();
  final _resourceId = TextEditingController(text: 'seed-tts-2.0');
  final _speaker = TextEditingController();

  bool _enabled = false;
  DoubaoTtsAuthMode _authMode = DoubaoTtsAuthMode.appToken;
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
    _appId.dispose();
    _accessKey.dispose();
    _resourceId.dispose();
    _speaker.dispose();
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
      _authMode = cfg.authMode;
      _apiKey.text = cfg.apiKey;
      _appId.text = cfg.appId;
      _accessKey.text = cfg.accessKey;
      _resourceId.text = cfg.resourceId.trim().isEmpty
          ? 'seed-tts-2.0'
          : cfg.resourceId;
      _speaker.text = cfg.speaker;
      _enabled = cfg.enabled;
    }
    setState(() => _didHydrate = true);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final payload = DoubaoTtsConfig(
      enabled: _enabled,
      authMode: _authMode,
      apiKey: _apiKey.text.trim(),
      appId: _appId.text.trim(),
      accessKey: _accessKey.text.trim(),
      resourceId: _resourceId.text.trim().isEmpty
          ? 'seed-tts-2.0'
          : _resourceId.text.trim(),
      speaker: _speaker.text.trim(),
    );
    if (!payload.isConfigured) {
      setState(() {
        _err = _authMode == DoubaoTtsAuthMode.apiKey
            ? '请填写 API Key、Resource ID 与 Speaker'
            : '请填写 APP ID、Access Token、Resource ID 与 Speaker';
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
      _authMode = DoubaoTtsAuthMode.appToken;
      _apiKey.clear();
      _appId.clear();
      _accessKey.clear();
      _resourceId.text = 'seed-tts-2.0';
      _speaker.clear();
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
                : (v) {
                    setState(() => _enabled = v);
                  },
            title: const Text('启用新消息语音播报'),
            contentPadding: EdgeInsets.zero,
          ),
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
                  : () => unawaited(
                      keepAlive.openBatteryOptimizationSettings(),
                    ),
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
          DropdownButtonFormField<DoubaoTtsAuthMode>(
            initialValue: _authMode,
            decoration: const InputDecoration(
              labelText: '鉴权方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: DoubaoTtsAuthMode.appToken,
                child: Text('服务接口认证信息'),
              ),
              DropdownMenuItem(
                value: DoubaoTtsAuthMode.apiKey,
                child: Text('新版 API Key'),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _authMode = v);
                  },
          ),
          const SizedBox(height: 12),
          if (_authMode == DoubaoTtsAuthMode.apiKey)
            TextField(
              controller: _apiKey,
              decoration: const InputDecoration(
                labelText: '豆包 API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_busy,
              autocorrect: false,
            )
          else ...[
            TextField(
              controller: _appId,
              decoration: const InputDecoration(
                labelText: 'APP ID',
                border: OutlineInputBorder(),
              ),
              enabled: !_busy,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accessKey,
              decoration: const InputDecoration(
                labelText: 'Access Token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_busy,
              autocorrect: false,
            ),
          ],
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
