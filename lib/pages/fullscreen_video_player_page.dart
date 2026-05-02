import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../media/fullscreen_video_source.dart';
import '../widgets/fullscreen_video_control_bar.dart';

/// Key for the opaque tap layer that toggles chrome visibility (widget tests).
const ValueKey<String> kFullscreenVideoPlayerTapLayerKey =
    ValueKey<String>('fullscreen_video_player_tap_layer');

typedef FullscreenVideoControllerFactory = VideoPlayerController Function(
  FullscreenVideoSource source,
);

class FullscreenVideoPlayerPage extends StatefulWidget {
  const FullscreenVideoPlayerPage({
    super.key,
    required this.source,
    this.controllerFactory,
  });

  final FullscreenVideoSource source;
  final FullscreenVideoControllerFactory? controllerFactory;

  @override
  State<FullscreenVideoPlayerPage> createState() =>
      FullscreenVideoPlayerPageState();
}

class FullscreenVideoPlayerPageState extends State<FullscreenVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _controlsVisible = true;
  String? _error;

  bool _wasPlayingBeforeSeek = false;
  bool _isSeeking = false;
  double? _dragValue;
  Timer? _autoHideTimer;

  VideoPlayerController _createController() {
    final factory = widget.controllerFactory;
    if (factory != null) return factory(widget.source);
    return VideoPlayerController.file(File(widget.source.filePath));
  }

  Future<void> _init() async {
    final controller = _createController();
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      controller.addListener(_handleControllerChanged);
      if (mounted) {
        setState(() => _loading = false);
        _scheduleAutoHide();
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

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    final ended = controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying;
    if (ended) {
      _cancelAutoHide();
      if (mounted) {
        setState(() => _controlsVisible = true);
      }
      return;
    }
    if (mounted) setState(() {});
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  void _cancelAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _scheduleAutoHide() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isPlaying ||
        _isSeeking) {
      return;
    }
    _cancelAutoHide();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  @visibleForTesting
  void debugHandleSeekStart(double value) => _handleSeekStart(value);

  @visibleForTesting
  void debugHandleSeekChanged(double value) => _handleSeekChanged(value);

  @visibleForTesting
  Future<void> debugHandleSeekEnd(double value) => _handleSeekEnd(value);

  void _handleSeekStart(double value) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _wasPlayingBeforeSeek = controller.value.isPlaying;
    _isSeeking = true;
    _dragValue = value;
    _cancelAutoHide();
  }

  void _handleSeekChanged(double value) {
    setState(() => _dragValue = value);
  }

  Future<void> _handleSeekEnd(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final target = Duration(
      milliseconds: (controller.value.duration.inMilliseconds * value).round(),
    );
    await controller.seekTo(target);
    if (_wasPlayingBeforeSeek) {
      await controller.play();
    } else {
      await controller.pause();
    }
    setState(() {
      _isSeeking = false;
      _dragValue = null;
    });
    _scheduleAutoHide();
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final ended = controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero;
    if (ended) {
      await controller.seekTo(Duration.zero);
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      _cancelAutoHide();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await controller.play();
      if (mounted) setState(() => _controlsVisible = true);
      _scheduleAutoHide();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    _cancelAutoHide();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_handleControllerChanged);
      unawaited(controller.dispose());
    }
    if (widget.source.ownsFile) {
      try {
        File(widget.source.filePath).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          key: kFullscreenVideoPlayerTapLayerKey,
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Text(
                    '视频加载失败',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              else if (controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: Hero(
                      tag: widget.source.heroTag,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Text(
                        widget.source.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              if (_controlsVisible &&
                  controller != null &&
                  controller.value.isInitialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Builder(
                    builder: (context) {
                      final duration = controller.value.duration;
                      final progressValue = (_dragValue ??
                              (duration.inMilliseconds == 0
                                  ? 0.0
                                  : controller.value.position.inMilliseconds /
                                      duration.inMilliseconds))
                          .clamp(0.0, 1.0);
                      final displayPosition = _dragValue == null
                          ? controller.value.position
                          : Duration(
                              milliseconds: (duration.inMilliseconds *
                                      _dragValue!)
                                  .round(),
                            );
                      return FullscreenVideoControlBar(
                        isPlaying: controller.value.isPlaying,
                        position: displayPosition,
                        duration: duration,
                        progressValue: progressValue,
                        onPlayPause: () => unawaited(_togglePlayPause()),
                        onChanged: _handleSeekChanged,
                        onChangeStart: _handleSeekStart,
                        onChangeEnd: (value) =>
                            unawaited(_handleSeekEnd(value)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
