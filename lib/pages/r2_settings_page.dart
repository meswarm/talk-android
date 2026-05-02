import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../r2/r2_credential_store.dart';
import '../r2/r2_models.dart';
import '../r2/r2_service.dart';
import '../theme/app_colors.dart';

class R2SettingsPage extends StatefulWidget {
  const R2SettingsPage({super.key});

  @override
  State<R2SettingsPage> createState() => _R2SettingsPageState();
}

class _R2SettingsPageState extends State<R2SettingsPage> {
  final _accessKeyId = TextEditingController();
  final _secretAccessKey = TextEditingController();
  final _accountId = TextEditingController();
  final _defaultBucket = TextEditingController();
  final _region = TextEditingController(text: 'auto');

  bool _busy = false;
  String? _err;
  /// 已从本机读入过已保存凭据（避免异步返回后覆盖用户正在输入的内容）。
  bool _didHydrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_hydrateFromSavedCredentials());
    });
  }

  Future<void> _hydrateFromSavedCredentials() async {
    if (_didHydrate || !mounted) return;
    try {
      var payload = context.read<R2Service>().session;
      payload ??= await R2CredentialStore.loadPayload();
      if (!mounted) return;
      final cred = payload;
      if (cred == null) return;
      setState(() {
        _accessKeyId.text = cred.accessKeyId;
        _secretAccessKey.text = cred.secretAccessKey;
        _accountId.text = cred.accountId;
        _defaultBucket.text = cred.defaultBucket;
        _region.text =
            cred.region.trim().isEmpty ? 'auto' : cred.region.trim();
        _didHydrate = true;
      });
    } catch (_) {
      if (mounted) setState(() => _didHydrate = true);
    }
  }

  @override
  void dispose() {
    _accessKeyId.dispose();
    _secretAccessKey.dispose();
    _accountId.dispose();
    _defaultBucket.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _err = null;
      _busy = true;
    });
    final payload = R2SecretPayload(
      accessKeyId: _accessKeyId.text.trim(),
      secretAccessKey: _secretAccessKey.text.trim(),
      accountId: _accountId.text.trim(),
      defaultBucket: _defaultBucket.text.trim(),
      region: _region.text.trim().isEmpty ? 'auto' : _region.text.trim(),
    );
    if (payload.accessKeyId.isEmpty ||
        payload.secretAccessKey.isEmpty ||
        payload.accountId.isEmpty ||
        payload.defaultBucket.isEmpty) {
      setState(() {
        _err = '请填写 Access Key、Secret Key、Account ID 与默认 Bucket';
        _busy = false;
      });
      return;
    }
    try {
      await context.read<R2Service>().saveCredentials(payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 R2 凭据'),
        content: const Text('将删除本机安全存储中的凭据，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<R2Service>().forgetCredentials();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('R2 对象存储'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '凭据仅保存在本机系统安全存储中，不会发往 Talk 服务器。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          if (_didHydrate && _accessKeyId.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '若曾保存过，下方会显示当前本机凭据；Secret Key 以圆点掩码显示。修改后请再次点击保存。',
              style: TextStyle(fontSize: 12, color: sub),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _accessKeyId,
            decoration: const InputDecoration(
              labelText: 'Access Key ID',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretAccessKey,
            decoration: const InputDecoration(
              labelText: 'Secret Access Key',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountId,
            decoration: const InputDecoration(
              labelText: 'Cloudflare Account ID',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _defaultBucket,
            decoration: const InputDecoration(
              labelText: '默认 Bucket',
              border: OutlineInputBorder(),
            ),
            enabled: !_busy,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _region,
            decoration: const InputDecoration(
              labelText: 'Region',
              hintText: 'auto',
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
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _forget,
            child: const Text('清除本机凭据'),
          ),
        ],
      ),
    );
  }
}
