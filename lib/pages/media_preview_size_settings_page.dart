import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../media/media_preview_sizes.dart';
import '../providers/media_preview_size_provider.dart';
import '../theme/app_colors.dart';

class MediaPreviewSizeSettingsPage extends StatefulWidget {
  const MediaPreviewSizeSettingsPage({super.key, required this.contextType});

  final MediaPreviewContext contextType;

  @override
  State<MediaPreviewSizeSettingsPage> createState() =>
      _MediaPreviewSizeSettingsPageState();
}

class _MediaPreviewSizeSettingsPageState
    extends State<MediaPreviewSizeSettingsPage> {
  late MediaPreviewSizes _sizes;
  bool _busy = false;

  String get _title {
    return switch (widget.contextType) {
      MediaPreviewContext.bubble => '普通气泡媒体尺寸',
      MediaPreviewContext.table => '表格内媒体尺寸',
    };
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<MediaPreviewSizeProvider>();
    _sizes = provider.sizesFor(widget.contextType);
  }

  Future<void> _save(MediaPreviewSizes sizes) async {
    setState(() {
      _busy = true;
      _sizes = sizes.clamp();
    });
    final provider = context.read<MediaPreviewSizeProvider>();
    try {
      switch (widget.contextType) {
        case MediaPreviewContext.bubble:
          await provider.setBubbleSizes(_sizes);
        case MediaPreviewContext.table:
          await provider.setTableSizes(_sizes);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final defaults = switch (widget.contextType) {
      MediaPreviewContext.bubble => MediaPreviewSizes.bubbleDefaults,
      MediaPreviewContext.table => MediaPreviewSizes.tableDefaults,
    };
    await _save(defaults);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.contextType == MediaPreviewContext.table
                ? '表格内媒体用于概览，建议保持较小；点击后仍可全屏查看。'
                : '普通气泡媒体用于聊天预览，点击后可全屏查看。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          const SizedBox(height: 18),
          _MediaSizeSection(
            title: '图片预览',
            widthValue: _sizes.imageWidth,
            widthMin: MediaPreviewSizes.minImageWidth,
            widthMax: MediaPreviewSizes.maxImageWidth,
            heightValue: _sizes.imageHeight,
            heightMin: MediaPreviewSizes.minImageHeight,
            heightMax: MediaPreviewSizes.maxImageHeight,
            enabled: !_busy,
            onWidthChanged: (v) => _save(_sizes.copyWith(imageWidth: v)),
            onHeightChanged: (v) => _save(_sizes.copyWith(imageHeight: v)),
          ),
          _MediaSizeSection(
            title: '视频预览',
            widthValue: _sizes.videoWidth,
            widthMin: MediaPreviewSizes.minVideoWidth,
            widthMax: MediaPreviewSizes.maxVideoWidth,
            heightValue: _sizes.videoHeight,
            heightMin: MediaPreviewSizes.minVideoHeight,
            heightMax: MediaPreviewSizes.maxVideoHeight,
            enabled: !_busy,
            onWidthChanged: (v) => _save(_sizes.copyWith(videoWidth: v)),
            onHeightChanged: (v) => _save(_sizes.copyWith(videoHeight: v)),
          ),
          _MediaSizeSection(
            title: '音频卡片',
            widthValue: _sizes.audioWidth,
            widthMin: MediaPreviewSizes.minCardWidth,
            widthMax: MediaPreviewSizes.maxCardWidth,
            heightValue: _sizes.audioHeight,
            heightMin: MediaPreviewSizes.minCardHeight,
            heightMax: MediaPreviewSizes.maxCardHeight,
            enabled: !_busy,
            onWidthChanged: (v) => _save(_sizes.copyWith(audioWidth: v)),
            onHeightChanged: (v) => _save(_sizes.copyWith(audioHeight: v)),
          ),
          _MediaSizeSection(
            title: '文件卡片',
            widthValue: _sizes.fileWidth,
            widthMin: MediaPreviewSizes.minCardWidth,
            widthMax: MediaPreviewSizes.maxCardWidth,
            heightValue: _sizes.fileHeight,
            heightMin: MediaPreviewSizes.minCardHeight,
            heightMax: MediaPreviewSizes.maxCardHeight,
            enabled: !_busy,
            onWidthChanged: (v) => _save(_sizes.copyWith(fileWidth: v)),
            onHeightChanged: (v) => _save(_sizes.copyWith(fileHeight: v)),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _busy ? null : _reset,
            child: const Text('恢复默认'),
          ),
        ],
      ),
    );
  }
}

class _MediaSizeSection extends StatelessWidget {
  const _MediaSizeSection({
    required this.title,
    required this.widthValue,
    required this.widthMin,
    required this.widthMax,
    required this.heightValue,
    required this.heightMin,
    required this.heightMax,
    required this.enabled,
    required this.onWidthChanged,
    required this.onHeightChanged,
  });

  final String title;
  final int widthValue;
  final int widthMin;
  final int widthMax;
  final int heightValue;
  final int heightMin;
  final int heightMax;
  final bool enabled;
  final ValueChanged<int> onWidthChanged;
  final ValueChanged<int> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ${widthValue}x$heightValue',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          _SizeSlider(
            title: '宽度',
            value: widthValue,
            min: widthMin,
            max: widthMax,
            enabled: enabled,
            onChanged: onWidthChanged,
          ),
          _SizeSlider(
            title: '高度',
            value: heightValue,
            min: heightMin,
            max: heightMax,
            enabled: enabled,
            onChanged: onHeightChanged,
          ),
        ],
      ),
    );
  }
}

class _SizeSlider extends StatelessWidget {
  const _SizeSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final titleColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, color: titleColor),
                ),
              ),
              Text(
                '$value px',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value px',
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ],
      ),
    );
  }
}
