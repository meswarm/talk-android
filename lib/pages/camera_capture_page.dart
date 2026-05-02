import 'dart:async';
import 'dart:io' show File;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../composer/composer_media_result.dart';

/// 自定义相机：点按拍照、长按录像（最长 15s）、确认后返回 [ComposerMediaResult]（不在此页上传）。
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    super.key,
    this.cameraListProvider = availableCameras,
    this.requestCameraPermission = _defaultRequestCameraPermission,
  });

  /// 可注入以便测试（例如返回空列表模拟无相机）。
  @visibleForTesting
  final Future<List<CameraDescription>> Function() cameraListProvider;

  /// 可注入以便在 widget 测试中固定为已授权。
  @visibleForTesting
  final Future<PermissionStatus> Function() requestCameraPermission;

  static Future<PermissionStatus> _defaultRequestCameraPermission() =>
      Permission.camera.request();

  /// 与 [CameraCapturePage] 相同，但显式命名供测试读取。
  static const Duration maxVideoDuration = Duration(seconds: 15);

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

/// 用户可见状态（预览 / 录制 / 确认），用于结构测试。
enum CameraCaptureVisiblePhase {
  initializing,
  previewing,
  recording,
  reviewingPhoto,
  reviewingVideo,
  error,
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  bool _initializing = true;
  String? _errorMessage;

  Uint8List? _photoBytes;
  XFile? _videoFile;
  Duration? _videoDuration;

  VideoPlayerController? _reviewVideo;

  Timer? _maxRecordTimer;
  Timer? _uiTicker;
  DateTime? _recordStarted;

  bool _recording = false;

  CameraCaptureVisiblePhase get _visiblePhase {
    if (_errorMessage != null) return CameraCaptureVisiblePhase.error;
    if (_initializing) return CameraCaptureVisiblePhase.initializing;
    if (_photoBytes != null) return CameraCaptureVisiblePhase.reviewingPhoto;
    if (_videoFile != null) return CameraCaptureVisiblePhase.reviewingVideo;
    if (_recording) return CameraCaptureVisiblePhase.recording;
    return CameraCaptureVisiblePhase.previewing;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final cam = await widget.requestCameraPermission();
    if (!mounted) return;
    if (!cam.isGranted) {
      setState(() {
        _initializing = false;
        _errorMessage = '需要相机权限';
      });
      return;
    }

    try {
      _cameras = await widget.cameraListProvider();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorMessage = '无法访问相机: $e';
      });
      return;
    }

    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() {
        _initializing = false;
        _errorMessage = '没有可用相机';
      });
      return;
    }

    await _setActiveCamera(_cameraIndex);
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _setActiveCamera(int index) async {
    await _controller?.dispose();
    _controller = null;

    final desc = _cameras[index];
    final next = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await next.initialize();
    if (!mounted) {
      await next.dispose();
      return;
    }
    _controller = next;
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _recording) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    try {
      await _setActiveCamera(_cameraIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换摄像头失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _takePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _recording) return;
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      setState(() => _photoBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _recording) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录像')),
        );
      }
      return;
    }

    try {
      await c.startVideoRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('开始录像失败: $e')),
        );
      }
      return;
    }

    _recordStarted = DateTime.now();
    _recording = true;
    _maxRecordTimer?.cancel();
    _maxRecordTimer = Timer(CameraCapturePage.maxVideoDuration, _onMaxDurationStop);
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  Future<void> _onMaxDurationStop() async {
    if (!_recording) return;
    await _finishRecording();
  }

  Future<void> _stopRecordingFromGesture() async {
    if (!_recording) return;
    await _finishRecording();
  }

  Future<void> _finishRecording() async {
    final c = _controller;
    if (c == null || !_recording) return;

    _maxRecordTimer?.cancel();
    _maxRecordTimer = null;
    _uiTicker?.cancel();
    _uiTicker = null;

    final started = _recordStarted;
    _recordStarted = null;
    _recording = false;

    XFile? file;
    try {
      file = await c.stopVideoRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止录像失败: $e')),
        );
      }
      setState(() {});
      return;
    }

    if (!mounted) return;
    var elapsed =
        started != null ? DateTime.now().difference(started) : Duration.zero;
    if (elapsed > CameraCapturePage.maxVideoDuration) {
      elapsed = CameraCapturePage.maxVideoDuration;
    }

    await _reviewVideo?.dispose();
    _reviewVideo = null;

    final ctl = VideoPlayerController.file(File(file.path));
    try {
      await ctl.initialize();
    } catch (e) {
      await ctl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法预览视频: $e')),
        );
      }
      return;
    }

    if (!mounted) {
      await ctl.dispose();
      return;
    }

    _videoFile = file;
    _videoDuration = elapsed;
    _reviewVideo = ctl;
    await ctl.setLooping(true);
    await ctl.play();
    setState(() {});
  }

  void _retake() {
    _maxRecordTimer?.cancel();
    _uiTicker?.cancel();
    unawaited(_reviewVideo?.dispose());
    _reviewVideo = null;
    _photoBytes = null;
    _videoFile = null;
    _videoDuration = null;
    _recording = false;
    _recordStarted = null;
    setState(() {});
  }

  Future<void> _confirm() async {
    final photo = _photoBytes;
    final vid = _videoFile;
    final dur = _videoDuration;

    if (photo != null) {
      final name = 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mime = lookupMimeType(name, headerBytes: photo) ?? 'image/jpeg';
      if (!mounted) return;
      Navigator.of(context).pop(
        ComposerMediaResult(bytes: photo, fileName: name, mime: mime),
      );
      return;
    }

    if (vid != null) {
      final bytes = await vid.readAsBytes();
      if (!mounted || bytes.isEmpty) return;
      final name = 'capture_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final mime = lookupMimeType(name, headerBytes: bytes) ?? 'video/mp4';
      if (!mounted) return;
      Navigator.of(context).pop(
        ComposerMediaResult(
          bytes: bytes,
          fileName: name,
          mime: mime,
          videoDuration: dur,
        ),
      );
      return;
    }
  }

  Duration get _recordElapsed {
    final start = _recordStarted;
    if (!_recording || start == null) return Duration.zero;
    final e = DateTime.now().difference(start);
    return e > CameraCapturePage.maxVideoDuration
        ? CameraCapturePage.maxVideoDuration
        : e;
  }

  @override
  void dispose() {
    _maxRecordTimer?.cancel();
    _uiTicker?.cancel();
    unawaited(_reviewVideo?.dispose());
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _visiblePhase;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(switch (phase) {
          CameraCaptureVisiblePhase.recording => '录像中',
          CameraCaptureVisiblePhase.reviewingPhoto ||
          CameraCaptureVisiblePhase.reviewingVideo =>
            '确认',
          _ => '相机',
        }),
        actions: [
          if (_cameras.length > 1 &&
              (phase == CameraCaptureVisiblePhase.previewing ||
                  phase == CameraCaptureVisiblePhase.recording))
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              tooltip: '切换摄像头',
              onPressed: _flipCamera,
            ),
        ],
      ),
      body: SafeArea(
        child: switch (phase) {
          CameraCaptureVisiblePhase.initializing => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          CameraCaptureVisiblePhase.error => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage ?? '错误',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          CameraCaptureVisiblePhase.reviewingPhoto => _ReviewPhoto(
              bytes: _photoBytes!,
              onRetake: _retake,
              onConfirm: _confirm,
            ),
          CameraCaptureVisiblePhase.reviewingVideo => _ReviewVideo(
              controller: _reviewVideo!,
              onRetake: _retake,
              onConfirm: _confirm,
            ),
          _ => _buildCameraPreview(phase),
        },
      ),
    );
  }

  Widget _buildCameraPreview(CameraCaptureVisiblePhase phase) {
    final c = _controller;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (c != null && c.value.isInitialized)
                ColoredBox(
                  color: Colors.black,
                  child: Builder(
                    builder: (context) {
                      final ps = c.value.previewSize;
                      if (ps == null) {
                        return CameraPreview(c);
                      }
                      return FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: ps.height,
                          height: ps.width,
                          child: CameraPreview(c),
                        ),
                      );
                    },
                  ),
                ),
              if (phase == CameraCaptureVisiblePhase.recording)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_recordElapsed),
                            key: const Key('camera-recording-timer'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/ ${_formatDuration(CameraCapturePage.maxVideoDuration)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: GestureDetector(
            key: const Key('camera-shutter-area'),
            onTap: phase == CameraCaptureVisiblePhase.previewing &&
                    !_initializing
                ? _takePhoto
                : null,
            onLongPressStart: phase == CameraCaptureVisiblePhase.previewing &&
                    !_initializing
                ? (_) => unawaited(_startRecording())
                : null,
            onLongPressEnd: (_) => unawaited(_stopRecordingFromGesture()),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: phase == CameraCaptureVisiblePhase.recording
                    ? Colors.red.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
              child: Center(
                child: Container(
                  key: const Key('camera-shutter'),
                  width: phase == CameraCaptureVisiblePhase.recording ? 28 : 56,
                  height: phase == CameraCaptureVisiblePhase.recording ? 28 : 56,
                  decoration: BoxDecoration(
                    shape: phase == CameraCaptureVisiblePhase.recording
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius:
                        phase == CameraCaptureVisiblePhase.recording
                            ? BorderRadius.circular(4)
                            : null,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Text(
          '点按拍照 · 长按录像（最长 15 秒）',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }
}

class _ReviewPhoto extends StatelessWidget {
  const _ReviewPhoto({
    required this.bytes,
    required this.onRetake,
    required this.onConfirm,
  });

  final Uint8List bytes;
  final VoidCallback onRetake;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Image.memory(bytes, fit: BoxFit.contain)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('camera-retake'),
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('重拍'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('camera-confirm'),
                  onPressed: () => unawaited(onConfirm()),
                  child: const Text('插入 Markdown'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewVideo extends StatelessWidget {
  const _ReviewVideo({
    required this.controller,
    required this.onRetake,
    required this.onConfirm,
  });

  final VideoPlayerController controller;
  final VoidCallback onRetake;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final ratio = controller.value.aspectRatio == 0
        ? 16 / 9
        : controller.value.aspectRatio;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: ratio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('camera-retake'),
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('重拍'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('camera-confirm'),
                  onPressed: () => unawaited(onConfirm()),
                  child: const Text('插入 Markdown'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
