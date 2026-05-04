import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/matrix_authenticated_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Profile? _profile;
  bool _loading = true;
  bool _saving = false;
  Uri? _avatarUri;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    final client = auth.matrixService.client;

    try {
      final profile = await client.fetchOwnProfile();
      Uri? avatarUri;
      if (profile.avatarUrl != null) {
        try {
          avatarUri = await profile.avatarUrl!.getDownloadUri(client);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _avatarUri = avatarUri;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('加载资料失败: $e');
      }
    }
  }

  Future<void> _editDisplayName() async {
    final auth = context.read<AuthProvider>();
    final client = auth.matrixService.client;
    final controller = TextEditingController(text: _profile?.displayName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新昵称'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    setState(() => _saving = true);
    try {
      await client.setProfileField(client.userID!, 'displayname', {
        'displayname': newName,
      });
      await _loadProfile();
      if (mounted) _showSuccess('昵称已更新');
    } catch (e) {
      if (mounted) _showError('修改失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    final auth = context.read<AuthProvider>();
    final client = auth.matrixService.client;
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (_profile?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('移除头像', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );

    // source == null 且底部弹窗被关闭（点击外部），什么都不做
    // 这里用特殊逻辑：如果选择了"移除头像"，source 传 null
    // 但 showModalBottomSheet 返回 null 也表示关闭

    if (source == null && _profile?.avatarUrl == null) return;

    setState(() => _saving = true);

    try {
      if (source == null) {
        // 移除头像
        await client.setAvatar(null);
      } else {
        final pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        );
        if (pickedFile == null) {
          setState(() => _saving = false);
          return;
        }

        final bytes = await pickedFile.readAsBytes();
        final fileName = pickedFile.name;
        await client.setAvatar(MatrixFile(bytes: bytes, name: fileName));
      }

      await _loadProfile();
      if (mounted) _showSuccess('头像已更新');
    } catch (e) {
      if (mounted) _showError('头像更新失败: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出登录后需要重新输入账号密码'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await auth.logout();
    if (mounted) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final client = auth.matrixService.client;
    final userId = client.userID ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  children: [
                    const SizedBox(height: 32),
                    // 头像
                    Center(
                      child: GestureDetector(
                        onTap: _saving ? null : _changeAvatar,
                        child: Stack(
                          children: [
                            MatrixAuthenticatedSquareAvatar(
                              uri: _avatarUri,
                              client: client,
                              size: 100,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              fallback: Text(
                                (_profile?.displayName ?? userId).isNotEmpty
                                    ? (_profile?.displayName ?? userId)[0]
                                          .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBackground
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 昵称
                    _buildProfileItem(
                      isDark: isDark,
                      icon: Icons.person_outline,
                      label: '昵称',
                      value: _profile?.displayName ?? '未设置',
                      onTap: _saving ? null : _editDisplayName,
                    ),
                    _buildDivider(isDark),

                    // Matrix ID（不可编辑）
                    _buildProfileItem(
                      isDark: isDark,
                      icon: Icons.alternate_email,
                      label: 'Matrix ID',
                      value: userId,
                      onTap: null,
                    ),
                    _buildDivider(isDark),

                    // 服务器
                    _buildProfileItem(
                      isDark: isDark,
                      icon: Icons.dns_outlined,
                      label: '服务器',
                      value:
                          auth.matrixService.client.homeserver?.toString() ??
                          '未知',
                      onTap: null,
                    ),
                    _buildDivider(isDark),

                    const SizedBox(height: 48),

                    // 退出登录
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: OutlinedButton(
                        onPressed: _saving ? null : _handleLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          '退出登录',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
                if (_saving)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileItem({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkAppBarText
                          : AppColors.lightAppBarText,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 58,
      color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
    );
  }
}
