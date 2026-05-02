import 'package:flutter/material.dart';

import '../media/fullscreen_image_source.dart';

enum FullscreenImageDisplayMode { fitScreen, fitWidth }

class FullscreenImageSurface extends StatelessWidget {
  const FullscreenImageSurface({
    super.key,
    required this.source,
    required this.displayMode,
  });

  final FullscreenImageSource source;
  final FullscreenImageDisplayMode displayMode;

  BoxFit get _fit =>
      displayMode == FullscreenImageDisplayMode.fitScreen ? BoxFit.contain : BoxFit.fitWidth;

  @override
  Widget build(BuildContext context) {
    switch (source.kind) {
      case FullscreenImageSourceKind.memory:
        return Image.memory(
          source.bytes!,
          fit: _fit,
          errorBuilder: (_, _, _) => const _ViewerLoadError(),
        );
      case FullscreenImageSourceKind.network:
        return Image.network(
          source.url!,
          fit: _fit,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, _, _) => const _ViewerLoadError(),
        );
      case FullscreenImageSourceKind.asset:
        return Image.asset(
          source.assetName!,
          fit: _fit,
          errorBuilder: (_, _, _) => const _ViewerLoadError(),
        );
    }
  }
}

class _ViewerLoadError extends StatelessWidget {
  const _ViewerLoadError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '图片加载失败',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
