import 'dart:typed_data';

enum FullscreenImageSourceKind { memory, network, asset }

class FullscreenImageSource {
  const FullscreenImageSource.memory({
    required this.bytes,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.memory,
        url = null,
        assetName = null;

  const FullscreenImageSource.network({
    required this.url,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.network,
        bytes = null,
        assetName = null;

  const FullscreenImageSource.asset({
    required this.assetName,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.asset,
        bytes = null,
        url = null;

  final FullscreenImageSourceKind kind;
  final Uint8List? bytes;
  final String? url;
  final String? assetName;
  final Object heroTag;
}
