import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:talk/media/fullscreen_image_source.dart';
import 'package:talk/widgets/fullscreen_image_viewer_route.dart';

import '../r2/r2_service.dart';
import '../theme/app_colors.dart';
import 'markdown_image_frame.dart';
import 'r2_markdown_card_shell.dart';

/// Inline `r2://` image for Markdown (parity with talkweb `useR2BlobUrl` + img).
class R2MarkdownImage extends StatefulWidget {
  final R2Service r2;
  final String ref;
  final bool isDark;
  final double maxImageHeight;
  final double? maxImageWidth;
  final VoidCallback? onDelete;

  const R2MarkdownImage({
    super.key,
    required this.r2,
    required this.ref,
    required this.isDark,
    this.maxImageHeight = 220,
    this.maxImageWidth,
    this.onDelete,
  });

  @override
  State<R2MarkdownImage> createState() => _R2MarkdownImageState();
}

class _R2MarkdownImageState extends State<R2MarkdownImage> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _error;

  double get _slotWidth {
    final width = widget.maxImageWidth;
    return width != null && width.isFinite ? width : 120;
  }

  double get _slotHeight =>
      widget.maxImageHeight.isFinite ? widget.maxImageHeight : 80;

  Widget _buildPreviewFrame({required Widget child}) {
    return MarkdownImageFrame(
      isDark: widget.isDark,
      maxHeight: widget.maxImageHeight,
      maxWidth: widget.maxImageWidth ?? double.infinity,
      child: SizedBox(
        width: _slotWidth,
        height: _slotHeight,
        child: Center(child: child),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(R2MarkdownImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref ||
        oldWidget.r2.session != widget.r2.session) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    if (widget.r2.session == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '解锁 R2 后可显示此图片';
        });
      }
      return;
    }
    try {
      final bytes = await widget.r2.fetchRefBytes(widget.ref);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF616161);
    if (_loading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _buildPreviewFrame(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isDark ? Colors.white54 : AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Text(
        '[R2 图片: $_error]',
        style: TextStyle(fontSize: 13, color: sub),
      );
    }
    final b = _bytes;
    if (b == null) {
      return const SizedBox.shrink();
    }
    return R2MarkdownCardShell(
      onDelete: widget.onDelete,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          openFullscreenImageViewer(
            context,
            source: FullscreenImageSource.memory(
              bytes: b,
              heroTag: 'r2-image-${widget.ref}',
            ),
          );
        },
        child: Hero(
          tag: 'r2-image-${widget.ref}',
          child: _buildPreviewFrame(
            child: Image.memory(
              b,
              width: _slotWidth,
              height: _slotHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Text('[图片解码失败]', style: TextStyle(color: sub, fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}
