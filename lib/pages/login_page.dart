import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../services/local_storage.dart';

enum _AuthMode { login, register }

/// Matrix 注册 API 使用本地用户名，不含 @ 与域名。
String _normalizeLocalpart(String raw) {
  final t = raw.trim();
  if (t.startsWith('@')) {
    final colon = t.indexOf(':');
    if (colon != -1) return t.substring(1, colon);
    return t.substring(1);
  }
  return t;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _password2Controller = TextEditingController();
  bool _obscurePassword = true;
  _AuthMode _mode = _AuthMode.login;
  String _localError = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadSavedPrefs();
  }

  Future<void> _loadSavedPrefs() async {
    final storage = LocalStorage();
    final serverUrl = await storage.getServerUrl();
    final username = await storage.getUsername();
    if (mounted) {
      _serverController.text = serverUrl;
      _usernameController.text = username;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _password2Controller.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _localError = '';
      _password2Controller.clear();
    });
  }

  Future<void> _handleSubmit() async {
    final auth = context.read<AuthProvider>();
    final serverUrl = _serverController.text.trim();
    final usernameRaw = _usernameController.text;
    final username = _mode == _AuthMode.register
        ? _normalizeLocalpart(usernameRaw)
        : usernameRaw.trim();

    setState(() => _localError = '');

    if (serverUrl.isEmpty) {
      setState(() => _localError = '请填写服务器地址');
      return;
    }
    if (username.isEmpty) {
      setState(() => _localError = '请填写用户名');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _localError = '请填写密码');
      return;
    }

    if (_mode == _AuthMode.register) {
      if (_password2Controller.text.isEmpty) {
        setState(() => _localError = '请填写确认密码');
        return;
      }
      if (_passwordController.text != _password2Controller.text) {
        setState(() => _localError = '两次输入的密码不一致');
        return;
      }
      if (_passwordController.text.length < 8) {
        setState(() {
          _localError = '密码至少 8 位（若服务器有更严策略，以服务器提示为准）';
        });
        return;
      }

      await auth.register(
        homeserverUrl: serverUrl,
        username: username,
        password: _passwordController.text,
      );

      if (auth.state == AuthState.authenticated) {
        await LocalStorage().saveLoginPrefs(
          serverUrl: serverUrl,
          username: username,
        );
      }
      return;
    }

    await auth.login(
      homeserverUrl: serverUrl,
      username: username,
      password: _passwordController.text,
    );

    if (auth.state == AuthState.authenticated) {
      await LocalStorage().saveLoginPrefs(
        serverUrl: serverUrl,
        username: username,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = auth.state == AuthState.loading;
    final subColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Talk',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkAppBarText
                          : AppColors.lightAppBarText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '基于 Matrix 协议的安全通讯',
                    style: TextStyle(
                      fontSize: 14,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: '登录或注册',
                    child: Row(
                      children: [
                        Expanded(
                          child: _LoginTab(
                            label: '登录',
                            selected: _mode == _AuthMode.login,
                            onTap: () => _setMode(_AuthMode.login),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _LoginTab(
                            label: '注册',
                            selected: _mode == _AuthMode.register,
                            onTap: () => _setMode(_AuthMode.register),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_mode == _AuthMode.register) ...[
                    const SizedBox(height: 12),
                    Text(
                      '注册需 Homeserver 允许简单流程（如同意条款 + dummy）。若需邮箱验证等，请先用 Element 注册再登录。',
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                  ],
                  const SizedBox(height: 32),

                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      prefixIcon: Icon(Icons.dns_outlined),
                      hintText: 'http://example.com:8448',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: _mode == _AuthMode.register
                          ? '用户名（本地部分，如 alice）'
                          : '用户名',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    autofillHints: _mode == _AuthMode.register
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!busy) _handleSubmit();
                    },
                  ),
                  if (_mode == _AuthMode.register) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password2Controller,
                      decoration: InputDecoration(
                        labelText: '确认密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ],
                  const SizedBox(height: 28),

                  if (_localError.isNotEmpty ||
                      (auth.state == AuthState.error &&
                          auth.errorMessage.isNotEmpty))
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _localError.isNotEmpty
                                  ? _localError
                                  : auth.errorMessage,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _handleSubmit(),
                      child: busy
                          ? Text(
                              _mode == _AuthMode.register ? '注册中…' : '登录中…',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            )
                          : Text(
                              _mode == _AuthMode.register
                                  ? '注册并登录'
                                  : '登录',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTab extends StatelessWidget {
  const _LoginTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
