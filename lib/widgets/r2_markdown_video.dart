import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../media/fullscreen_video_source.dart';
import '../r2/r2_service.dart';
import '../theme/app_colors.dart';
import 'chat_video_preview_card.dart';
import 'fullscreen_video_player_route.dart';
import 'markdown_image_frame.dart';
import 'r2_markdown_card_shell.dart';

/// Inline `r2://` video in Markdown: thumbnail preview; play opens fullscreen player.
class R2MarkdownVideo extends StatefulWidget {
  final R2Service r2;
  final String ref;
  final bool isDark;
  final double maxImageHeight;
  final double? maxImageWidth;
  final VoidCallback? onDelete;

  const R2MarkdownVideo({
    super.key,
    required this.r2,
    required this.ref,
    required this.isDark,
    this.maxImageHeight = 220,
    this.maxImageWidth,
    this.onDelete,
  });

  @override
  State<R2MarkdownVideo> createState() => _R2MarkdownVideoState();
}

class _R2MarkdownVideoState extends State<R2MarkdownVideo> {
  VideoPlayerController? _controller;
  String? _localPath;
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
      child: SizedBox(width: _slotWidth, height: _slotHeight, child: child),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(R2MarkdownVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref ||
        oldWidget.r2.session != widget.r2.session) {
      unawaited(_reload());
    }
  }

  Future<void> _reload() async {
    final old = _controller;
    _controller = null;
    _localPath = null;
    if (old != null) {
      await old.dispose();
    }
    if (mounted) {
      await _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.r2.session == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '解锁 R2 后可播放此视频';
        });
      }
      return;
    }
    VideoPlayerController? pending;
    try {
      final filePath = await widget.r2.fetchRefFile(widget.ref);
      _localPath = filePath;
      pending = VideoPlayerController.file(File(filePath));
      await pending.initialize();
      await pending.setLooping(false);
      if (!mounted) {
        await pending.dispose();
        return;
      }
      setState(() {
        _controller = pending;
        _loading = false;
      });
      pending = null;
    } catch (e) {
      await pending?.dispose();
      _localPath = null;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      unawaited(c.dispose());
    }
    super.dispose();
  }

  Future<void> _openFullscreen(BuildContext context) async {
    final originalPath = _localPath;
    final c = _controller;
    if (originalPath == null || c == null || !c.value.isInitialized) {
      return;
    }
    final heroTag = 'r2-video-${widget.ref}';
    final dir = await getTemporaryDirectory();
    final copyPath = p.join(
      dir.path,
      'talk_r2_vid_fs_${widget.ref.hashCode.abs()}.mp4',
    );
    try {
      await File(originalPath).copy(copyPath);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开视频')));
      }
      try {
        final f = File(copyPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return;
    }
    if (!context.mounted) {
      try {
        await File(copyPath).delete();
      } catch (_) {}
      return;
    }
    await openFullscreenVideoPlayer(
      context,
      source: FullscreenVideoSource(
        filePath: copyPath,
        heroTag: heroTag,
        durationHint: c.value.duration,
        ownsFile: true,
      ),
    );
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
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.isDark ? Colors.white54 : AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Text(
        '[R2 视频: $_error]',
        style: TextStyle(fontSize: 13, color: sub),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final ar = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;

    return R2MarkdownCardShell(
      onDelete: widget.onDelete,
      child: _buildPreviewFrame(
        child: ColoredBox(
          color: Colors.black,
          child: ChatVideoPreviewCard(
            duration: c.value.duration,
            onPlay: () {
              unawaited(_openFullscreen(context));
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: ar,
                child: Hero(
                  tag: 'r2-video-${widget.ref}',
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: c.value.size.width,
                      height: c.value.size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
