class FullscreenVideoSource {
  const FullscreenVideoSource({
    required this.filePath,
    required this.heroTag,
    this.durationHint,
    this.ownsFile = false,
    this.title = '视频',
  });

  final String filePath;
  final Object heroTag;
  final Duration? durationHint;
  final bool ownsFile;
  final String title;
}
