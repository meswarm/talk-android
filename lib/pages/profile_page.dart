import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import '../media/media_preview_sizes.dart';
import '../quick_extract/deepseek_quick_extract_service.dart';
import '../services/local_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/bubble_max_height_provider.dart';
import '../providers/media_preview_size_provider.dart';
import '../providers/text_scale_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/matrix_authenticated_image.dart';
import 'media_preview_size_settings_page.dart';
import 'deepseek_settings_page.dart';
import 'voice_announcement_settings_page.dart';

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

  /// 展开聊天 Markdown 区高度（屏幕高度百分比），与 [LocalStorage] 同步。
  int _composerHeightPct = LocalStorage.defaultComposerHeightPct;

  /// 聊天气泡 Markdown 收起态最大高度（屏幕高度百分比），与 [BubbleMaxHeightProvider] 同步。
  int _bubbleMaxHeightPct = LocalStorage.defaultBubbleMaxHeightPct;

  /// 插入聊天前是否压缩图片，与 [LocalStorage] 同步。
  bool _compressUploadImages = LocalStorage.defaultCompressUploadImages;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadComposerHeightSetting();
    _loadBubbleMaxHeightFromProvider();
    unawaited(_loadCompressUploadSetting());
  }

  void _loadBubbleMaxHeightFromProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final v = context.read<BubbleMaxHeightProvider>().pct;
      setState(() => _bubbleMaxHeightPct = v);
    });
  }

  Future<void> _loadComposerHeightSetting() async {
    final v = await LocalStorage().loadComposerHeightPct();
    if (mounted) setState(() => _composerHeightPct = v);
  }

  Future<void> _loadCompressUploadSetting() async {
    final v = await LocalStorage().loadCompressUploadImages();
    if (mounted) setState(() => _compressUploadImages = v);
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

  void _openVoiceAnnouncementSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VoiceAnnouncementSettingsPage()),
    );
  }

  void _openDeepSeekSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeepSeekSettingsPage()));
  }

  void _openMediaPreviewSizeSettings(MediaPreviewContext contextType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewSizeSettingsPage(contextType: contextType),
      ),
    );
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

                    // 全局字体
                    _buildFontScaleRow(isDark),
                    _buildDivider(isDark),

                    // 聊天展开输入区高度
                    _buildComposerHeightRow(isDark),
                    _buildDivider(isDark),

                    // 聊天气泡 Markdown 最大高度（收起时）
                    _buildBubbleMaxHeightRow(isDark),
                    _buildDivider(isDark),

                    // 聊天图片压缩上传
                    _buildCompressUploadRow(isDark),
                    _buildDivider(isDark),

                    _buildMediaPreviewSizeItem(
                      isDark: isDark,
                      contextType: MediaPreviewContext.bubble,
                    ),
                    _buildDivider(isDark),

                    _buildMediaPreviewSizeItem(
                      isDark: isDark,
                      contextType: MediaPreviewContext.table,
                    ),
                    _buildDivider(isDark),

                    _buildProfileItem(
                      isDark: isDark,
                      icon: Icons.smart_toy_outlined,
                      label: 'DeepSeek 配置',
                      value:
                          context
                              .watch<DeepSeekQuickExtractService>()
                              .isConfigured
                          ? '快速提取模型已配置'
                          : '快速提取使用的大模型',
                      onTap: _saving ? null : _openDeepSeekSettings,
                    ),
                    _buildDivider(isDark),

                    _buildProfileItem(
                      isDark: isDark,
                      icon: Icons.record_voice_over_outlined,
                      label: '语音播报',
                      value: '新消息到达时语音提醒',
                      onTap: _saving ? null : _openVoiceAnnouncementSettings,
                    ),

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

  Widget _buildFontScaleRow(bool isDark) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final tp = context.watch<TextScaleProvider>();
    final atMin = tp.step <= LocalStorage.minTextScaleStep;
    final atMax = tp.step >= LocalStorage.maxTextScaleStep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.format_size, size: 22, color: sub),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('界面字体', style: TextStyle(fontSize: 13, color: sub)),
                const SizedBox(height: 2),
                Text(
                  '相对标准每档约 10%，与系统字体大小叠加',
                  style: TextStyle(
                    fontSize: 11,
                    color: sub.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '减小',
            onPressed: atMin || _saving ? null : () => tp.decrement(),
            icon: Icon(
              Icons.remove_circle_outline,
              color: atMin ? sub.withValues(alpha: 0.35) : AppColors.primary,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              tp.stepLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkAppBarText
                    : AppColors.lightAppBarText,
              ),
            ),
          ),
          IconButton(
            tooltip: '增大',
            onPressed: atMax || _saving ? null : () => tp.increment(),
            icon: Icon(
              Icons.add_circle_outline,
              color: atMax ? sub.withValues(alpha: 0.35) : AppColors.primary,
            ),
          ),
          TextButton(
            onPressed: _saving || tp.step == 0 ? null : () => tp.reset(),
            child: const Text('恢复标准'),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleMaxHeightRow(bool isDark) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final min = LocalStorage.minBubbleMaxHeightPct.toDouble();
    final max = LocalStorage.maxBubbleMaxHeightPct.toDouble();
    final divisions =
        LocalStorage.maxBubbleMaxHeightPct - LocalStorage.minBubbleMaxHeightPct;
    final v = _bubbleMaxHeightPct;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 22, color: sub),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '聊天气泡最大高度',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '按屏幕高度比例，过长内容可点「展开」查看全文',
                      style: TextStyle(
                        fontSize: 11,
                        color: sub.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$v%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkAppBarText
                      : AppColors.lightAppBarText,
                ),
              ),
            ],
          ),
          Slider(
            value: v
                .clamp(
                  LocalStorage.minBubbleMaxHeightPct,
                  LocalStorage.maxBubbleMaxHeightPct,
                )
                .toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: '$v%',
            onChanged: _saving
                ? null
                : (nv) {
                    setState(() {
                      _bubbleMaxHeightPct = nv.round().clamp(
                        LocalStorage.minBubbleMaxHeightPct,
                        LocalStorage.maxBubbleMaxHeightPct,
                      );
                    });
                  },
            onChangeEnd: _saving
                ? null
                : (nv) async {
                    final n = nv.round().clamp(
                      LocalStorage.minBubbleMaxHeightPct,
                      LocalStorage.maxBubbleMaxHeightPct,
                    );
                    await context.read<BubbleMaxHeightProvider>().setPct(n);
                    if (mounted) setState(() => _bubbleMaxHeightPct = n);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildCompressUploadRow(bool isDark) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final titleColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.photo_size_select_large_outlined, size: 22, color: sub),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('图片压缩上传', style: TextStyle(fontSize: 13, color: sub)),
                    const SizedBox(width: 8),
                    Text(
                      _compressUploadImages ? '压缩' : '原图',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '开启后，插入聊天的图片会先压缩再上传，节省流量与存储；关闭则保留原始文件。GIF 不压缩。',
                  style: TextStyle(
                    fontSize: 11,
                    color: sub.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _compressUploadImages,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: titleColor.withValues(alpha: 0.65),
            inactiveTrackColor: sub.withValues(alpha: 0.35),
            onChanged: _saving
                ? null
                : (v) async {
                    setState(() => _compressUploadImages = v);
                    await LocalStorage().saveCompressUploadImages(v);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreviewSizeItem({
    required bool isDark,
    required MediaPreviewContext contextType,
  }) {
    final provider = context.watch<MediaPreviewSizeProvider>();
    final sizes = provider.sizesFor(contextType);
    final label = switch (contextType) {
      MediaPreviewContext.bubble => '普通气泡媒体尺寸',
      MediaPreviewContext.table => '表格内媒体尺寸',
    };
    return _buildProfileItem(
      isDark: isDark,
      icon: contextType == MediaPreviewContext.bubble
          ? Icons.photo_size_select_actual_outlined
          : Icons.table_chart_outlined,
      label: label,
      value:
          '图 ${sizes.imageWidth}x${sizes.imageHeight} / 视 ${sizes.videoWidth}x${sizes.videoHeight} / '
          '音 ${sizes.audioWidth}x${sizes.audioHeight} / 文 ${sizes.fileWidth}x${sizes.fileHeight}',
      onTap: _saving ? null : () => _openMediaPreviewSizeSettings(contextType),
    );
  }

  Widget _buildComposerHeightRow(bool isDark) {
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final min = LocalStorage.minComposerHeightPct.toDouble();
    final max = LocalStorage.maxComposerHeightPct.toDouble();
    final divisions =
        LocalStorage.maxComposerHeightPct - LocalStorage.minComposerHeightPct;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vertical_align_center_outlined, size: 22, color: sub),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '聊天展开输入区高度',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '按屏幕高度比例，在会话中展开 Markdown 输入时生效',
                      style: TextStyle(
                        fontSize: 11,
                        color: sub.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_composerHeightPct%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkAppBarText
                      : AppColors.lightAppBarText,
                ),
              ),
            ],
          ),
          Slider(
            value: _composerHeightPct
                .clamp(
                  LocalStorage.minComposerHeightPct,
                  LocalStorage.maxComposerHeightPct,
                )
                .toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: '$_composerHeightPct%',
            onChanged: _saving
                ? null
                : (v) {
                    setState(() {
                      _composerHeightPct = v.round().clamp(
                        LocalStorage.minComposerHeightPct,
                        LocalStorage.maxComposerHeightPct,
                      );
                    });
                  },
            onChangeEnd: _saving
                ? null
                : (v) async {
                    final n = v.round().clamp(
                      LocalStorage.minComposerHeightPct,
                      LocalStorage.maxComposerHeightPct,
                    );
                    await LocalStorage().saveComposerHeightPct(n);
                    if (mounted) setState(() => _composerHeightPct = n);
                  },
          ),
        ],
      ),
    );
  }
}
