import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../quick_extract/deepseek_config.dart';
import '../quick_extract/deepseek_quick_extract_service.dart';
import '../theme/app_colors.dart';

class DeepSeekSettingsPage extends StatefulWidget {
  const DeepSeekSettingsPage({super.key});

  @override
  State<DeepSeekSettingsPage> createState() => _DeepSeekSettingsPageState();
}

class _DeepSeekSettingsPageState extends State<DeepSeekSettingsPage> {
  final _apiKey = TextEditingController();
  final _baseUrl = TextEditingController(text: DeepSeekConfig.defaultBaseUrl);
  final _model = TextEditingController(text: DeepSeekConfig.defaultModel);

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
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    if (_didHydrate || !mounted) return;
    final service = context.read<DeepSeekQuickExtractService>();
    var cfg = service.config;
    if (cfg == null && service.loading) {
      await service.bootstrap();
      cfg = service.config;
    }
    if (!mounted) return;
    if (cfg != null) {
      _apiKey.text = cfg.apiKey;
      _baseUrl.text = cfg.baseUrl;
      _model.text = cfg.model;
    }
    setState(() => _didHydrate = true);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final config = DeepSeekConfig(
      apiKey: _apiKey.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
    ).normalized();
    if (!config.isConfigured) {
      setState(() {
        _busy = false;
        _err = '请填写 DeepSeek API Key';
      });
      return;
    }
    try {
      await context.read<DeepSeekQuickExtractService>().saveConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DeepSeek 配置已保存'),
          backgroundColor: AppColors.primary,
        ),
      );
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
        title: const Text('清除 DeepSeek 凭据'),
        content: const Text('将删除本机安全存储中的 DeepSeek 配置，确定继续？'),
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
      await context.read<DeepSeekQuickExtractService>().clearConfig();
      _apiKey.clear();
      _baseUrl.text = DeepSeekConfig.defaultBaseUrl;
      _model.text = DeepSeekConfig.defaultModel;
      if (mounted) setState(() {});
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
    try {
      await context.read<DeepSeekQuickExtractService>().runConnectivityTest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DeepSeek 测试完成'),
          backgroundColor: AppColors.primary,
        ),
      );
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

    return Scaffold(
      appBar: AppBar(title: const Text('DeepSeek 配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'API Key 仅保存在本机系统安全存储，不会发往 Talk 服务器。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            decoration: const InputDecoration(
              labelText: 'DeepSeek API Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _testConfig,
            child: const Text('测试'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _clear,
            child: const Text('清除本机配置'),
          ),
        ],
      ),
    );
  }
}
