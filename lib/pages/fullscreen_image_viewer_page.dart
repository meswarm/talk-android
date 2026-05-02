import 'package:flutter/material.dart';

import '../media/fullscreen_image_source.dart';
import '../widgets/fullscreen_image_surface.dart';

class FullscreenImageViewerPage extends StatefulWidget {
  const FullscreenImageViewerPage({super.key, required this.source});

  final FullscreenImageSource source;

  @override
  State<FullscreenImageViewerPage> createState() =>
      FullscreenImageViewerPageState();
}

class FullscreenImageViewerPageState extends State<FullscreenImageViewerPage> {
  final TransformationController _transform = TransformationController();
  final GlobalKey _viewerChildKey = GlobalKey();
  bool _toolbarVisible = true;
  FullscreenImageDisplayMode _mode = FullscreenImageDisplayMode.fitScreen;
  Offset? _lastFocalInChild;

  @visibleForTesting
  TransformationController get transformController => _transform;

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
  }

  void _setMode(FullscreenImageDisplayMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _transform.value = Matrix4.identity();
    });
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final ctx = _viewerChildKey.currentContext;
    if (ctx == null) {
      _lastFocalInChild = null;
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      _lastFocalInChild = null;
      return;
    }
    _lastFocalInChild = box.globalToLocal(details.globalPosition);
  }

  void _handleDoubleTap() {
    final currentScale = _transform.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }

    const zoom = 2.2;
    final focal = _lastFocalInChild;
    if (focal == null) {
      _transform.value = Matrix4.diagonal3Values(zoom, zoom, 1);
      return;
    }

    final dx = -focal.dx * (zoom - 1);
    final dy = -focal.dy * (zoom - 1);
    final m = Matrix4.identity();
    m.translateByDouble(dx, dy, 0, 1);
    m.scaleByDouble(zoom, zoom, 1, 1);
    _transform.value = m;
  }

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleToolbar,
                    onDoubleTapDown: _handleDoubleTapDown,
                    onDoubleTap: _handleDoubleTap,
                    child: SizedBox.expand(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 4,
                        panEnabled:
                            _transform.value.getMaxScaleOnAxis() > 1.01,
                        child: SizedBox(
                          key: _viewerChildKey,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Hero(
                            tag: widget.source.heroTag,
                            child: FullscreenImageSurface(
                              source: widget.source,
                              displayMode: _mode,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_toolbarVisible)
              Positioned(
                top: 0,
                left: 0,
                child: _ViewerTopBar(
                  mode: _mode,
                  onBack: () => Navigator.of(context).maybePop(),
                  onModeChanged: _setMode,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    required this.mode,
    required this.onBack,
    required this.onModeChanged,
  });

  final FullscreenImageDisplayMode mode;
  final VoidCallback onBack;
  final ValueChanged<FullscreenImageDisplayMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            PopupMenuButton<FullscreenImageDisplayMode>(
              initialValue: mode,
              onSelected: onModeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: FullscreenImageDisplayMode.fitScreen,
                  child: Text('适应屏幕'),
                ),
                PopupMenuItem(
                  value: FullscreenImageDisplayMode.fitWidth,
                  child: Text('适应宽度'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  mode == FullscreenImageDisplayMode.fitScreen ? '适应屏幕' : '适应宽度',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
