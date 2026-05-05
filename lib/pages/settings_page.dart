import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../media/media_preview_sizes.dart';
import '../providers/bubble_max_height_provider.dart';
import '../providers/media_preview_size_provider.dart';
import '../providers/text_scale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/local_storage.dart';
import '../theme/app_colors.dart';
import 'deepseek_settings_page.dart';
import 'media_preview_size_settings_page.dart';
import 'profile_page.dart';
import 'push_notification_settings_page.dart';
import 'r2_settings_page.dart';
import 'realtime_secretary_settings_page.dart';
import 'voice_announcement_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            title: '个人资料',
            subtitle: '头像、昵称、账号信息与退出登录',
            onTap: () => _push(context, const ProfilePage()),
          ),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'R2 存储',
            subtitle: '配置附件上传和下载所用的 R2 凭据',
            onTap: () => _push(context, const R2SettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: '外观',
            subtitle: '主题与界面字体',
            onTap: () => _push(context, const AppearanceSettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.chat_bubble_outline,
            title: '聊天界面',
            subtitle: '输入区高度、气泡高度与媒体预览尺寸',
            onTap: () => _push(context, const ChatInterfaceSettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.upload_file_outlined,
            title: '图片与上传',
            subtitle: '图片压缩上传',
            onTap: () => _push(context, const UploadSettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'AI 与快捷操作',
            subtitle: 'DeepSeek 快速提取配置',
            onTap: () => _push(context, const DeepSeekSettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.record_voice_over_outlined,
            title: '语音播报',
            subtitle: '豆包 TTS、常驻监听与合成参数',
            onTap: () => _push(context, const VoiceAnnouncementSettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.support_agent_outlined,
            title: '实时语音秘书',
            subtitle: '豆包实时语音、暗号唤醒与最近上下文',
            onTap: () => _push(context, const RealtimeSecretarySettingsPage()),
          ),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: '推送通知',
            subtitle: 'FCM Token 与系统通知测试',
            onTap: () => _push(context, const PushNotificationSettingsPage()),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final textScale = context.watch<TextScaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final atMin = textScale.step <= LocalStorage.minTextScaleStep;
    final atMax = textScale.step >= LocalStorage.maxTextScaleStep;

    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('主题'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('跟随系统'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('白天'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('夜间'),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (modes) {
              themeProvider.setThemeMode(modes.first);
            },
          ),
          const SizedBox(height: 28),
          const _SectionTitle('界面字体'),
          Text(
            '相对标准每档约 10%，与系统字体大小叠加。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: '减小',
                onPressed: atMin
                    ? null
                    : () => unawaited(textScale.decrement()),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    textScale.stepLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '增大',
                onPressed: atMax
                    ? null
                    : () => unawaited(textScale.increment()),
                icon: const Icon(Icons.add_circle_outline),
              ),
              TextButton(
                onPressed: textScale.step == 0
                    ? null
                    : () => unawaited(textScale.reset()),
                child: const Text('恢复标准'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatInterfaceSettingsPage extends StatefulWidget {
  const ChatInterfaceSettingsPage({super.key});

  @override
  State<ChatInterfaceSettingsPage> createState() =>
      _ChatInterfaceSettingsPageState();
}

class _ChatInterfaceSettingsPageState extends State<ChatInterfaceSettingsPage> {
  var _composerHeightPct = LocalStorage.defaultComposerHeightPct;

  @override
  void initState() {
    super.initState();
    unawaited(_loadComposerHeight());
  }

  Future<void> _loadComposerHeight() async {
    final value = await LocalStorage().loadComposerHeightPct();
    if (mounted) setState(() => _composerHeightPct = value);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleMaxHeight = context.watch<BubbleMaxHeightProvider>();
    final mediaPreview = context.watch<MediaPreviewSizeProvider>();
    final minComposer = LocalStorage.minComposerHeightPct.toDouble();
    final maxComposer = LocalStorage.maxComposerHeightPct.toDouble();
    final minBubble = LocalStorage.minBubbleMaxHeightPct.toDouble();
    final maxBubble = LocalStorage.maxBubbleMaxHeightPct.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('聊天界面')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('聊天展开输入区高度'),
          _PercentSlider(
            value: _composerHeightPct,
            min: minComposer,
            max: maxComposer,
            divisions:
                LocalStorage.maxComposerHeightPct -
                LocalStorage.minComposerHeightPct,
            onChanged: (v) => setState(() => _composerHeightPct = v),
            onChangeEnd: (v) =>
                unawaited(LocalStorage().saveComposerHeightPct(v)),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('聊天气泡最大高度'),
          _PercentSlider(
            value: bubbleMaxHeight.pct,
            min: minBubble,
            max: maxBubble,
            divisions:
                LocalStorage.maxBubbleMaxHeightPct -
                LocalStorage.minBubbleMaxHeightPct,
            onChanged: (v) => unawaited(bubbleMaxHeight.setPct(v)),
            onChangeEnd: (_) {},
          ),
          const SizedBox(height: 24),
          _MediaSizeEntry(
            icon: Icons.photo_size_select_actual_outlined,
            title: '普通气泡媒体尺寸',
            sizes: mediaPreview.bubbleSizes,
            onTap: () => _pushMediaSize(context, MediaPreviewContext.bubble),
          ),
          const Divider(height: 1),
          _MediaSizeEntry(
            icon: Icons.table_chart_outlined,
            title: '表格内媒体尺寸',
            sizes: mediaPreview.tableSizes,
            onTap: () => _pushMediaSize(context, MediaPreviewContext.table),
          ),
        ],
      ),
    );
  }

  static void _pushMediaSize(
    BuildContext context,
    MediaPreviewContext contextType,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaPreviewSizeSettingsPage(contextType: contextType),
      ),
    );
  }
}

class UploadSettingsPage extends StatefulWidget {
  const UploadSettingsPage({super.key});

  @override
  State<UploadSettingsPage> createState() => _UploadSettingsPageState();
}

class _UploadSettingsPageState extends State<UploadSettingsPage> {
  var _compressUploadImages = LocalStorage.defaultCompressUploadImages;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final value = await LocalStorage().loadCompressUploadImages();
    if (mounted) setState(() => _compressUploadImages = value);
  }

  Future<void> _setCompressUploadImages(bool value) async {
    setState(() => _compressUploadImages = value);
    await LocalStorage().saveCompressUploadImages(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片与上传')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _compressUploadImages,
            onChanged: (value) => unawaited(_setCompressUploadImages(value)),
            title: const Text('图片压缩上传'),
            subtitle: const Text('开启后，插入聊天的图片会先压缩再上传；关闭则保留原始文件。GIF 不压缩。'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return ListTile(
      leading: Icon(icon, color: sub),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min.round(), max.round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$clamped%',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Slider(
          value: clamped.toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: '$clamped%',
          onChanged: (v) => onChanged(v.round()),
          onChangeEnd: (v) => onChangeEnd(v.round()),
        ),
      ],
    );
  }
}

class _MediaSizeEntry extends StatelessWidget {
  const _MediaSizeEntry({
    required this.icon,
    required this.title,
    required this.sizes,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final MediaPreviewSizes sizes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        '图 ${sizes.imageWidth}x${sizes.imageHeight} / 视 ${sizes.videoWidth}x${sizes.videoHeight} / '
        '音 ${sizes.audioWidth}x${sizes.audioHeight} / 文 ${sizes.fileWidth}x${sizes.fileHeight}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
