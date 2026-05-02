enum MediaPreviewContext { bubble, table }

class MediaPreviewSizes {
  const MediaPreviewSizes({
    required this.imageWidth,
    required this.imageHeight,
    required this.videoWidth,
    required this.videoHeight,
    required this.audioWidth,
    required this.audioHeight,
    required this.fileWidth,
    required this.fileHeight,
  });

  final int imageWidth;
  final int imageHeight;
  final int videoWidth;
  final int videoHeight;
  final int audioWidth;
  final int audioHeight;
  final int fileWidth;
  final int fileHeight;

  static const bubbleDefaults = MediaPreviewSizes(
    imageWidth: 260,
    imageHeight: 220,
    videoWidth: 260,
    videoHeight: 220,
    audioWidth: 320,
    audioHeight: 64,
    fileWidth: 320,
    fileHeight: 64,
  );

  static const tableDefaults = MediaPreviewSizes(
    imageWidth: 96,
    imageHeight: 72,
    videoWidth: 96,
    videoHeight: 72,
    audioWidth: 240,
    audioHeight: 44,
    fileWidth: 180,
    fileHeight: 44,
  );

  static const minImageWidth = 40;
  static const maxImageWidth = 420;
  static const minImageHeight = 40;
  static const maxImageHeight = 360;
  static const minVideoWidth = 40;
  static const maxVideoWidth = 420;
  static const minVideoHeight = 40;
  static const maxVideoHeight = 360;
  static const minCardWidth = 96;
  static const maxCardWidth = 420;
  static const minCardHeight = 36;
  static const maxCardHeight = 120;

  MediaPreviewSizes clamp() {
    return MediaPreviewSizes(
      imageWidth: imageWidth.clamp(minImageWidth, maxImageWidth),
      imageHeight: imageHeight.clamp(minImageHeight, maxImageHeight),
      videoWidth: videoWidth.clamp(minVideoWidth, maxVideoWidth),
      videoHeight: videoHeight.clamp(minVideoHeight, maxVideoHeight),
      audioWidth: audioWidth.clamp(minCardWidth, maxCardWidth),
      audioHeight: audioHeight.clamp(minCardHeight, maxCardHeight),
      fileWidth: fileWidth.clamp(minCardWidth, maxCardWidth),
      fileHeight: fileHeight.clamp(minCardHeight, maxCardHeight),
    );
  }

  MediaPreviewSizes copyWith({
    int? imageWidth,
    int? imageHeight,
    int? videoWidth,
    int? videoHeight,
    int? audioWidth,
    int? audioHeight,
    int? fileWidth,
    int? fileHeight,
  }) {
    return MediaPreviewSizes(
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      audioWidth: audioWidth ?? this.audioWidth,
      audioHeight: audioHeight ?? this.audioHeight,
      fileWidth: fileWidth ?? this.fileWidth,
      fileHeight: fileHeight ?? this.fileHeight,
    ).clamp();
  }

  Map<String, dynamic> toJson() => {
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'videoWidth': videoWidth,
    'videoHeight': videoHeight,
    'audioWidth': audioWidth,
    'audioHeight': audioHeight,
    'fileWidth': fileWidth,
    'fileHeight': fileHeight,
  };

  factory MediaPreviewSizes.fromJson(
    Map<String, dynamic> json,
    MediaPreviewSizes defaults,
  ) {
    return MediaPreviewSizes(
      imageWidth: json['imageWidth'] as int? ?? defaults.imageWidth,
      imageHeight: json['imageHeight'] as int? ?? defaults.imageHeight,
      videoWidth: json['videoWidth'] as int? ?? defaults.videoWidth,
      videoHeight: json['videoHeight'] as int? ?? defaults.videoHeight,
      audioWidth: json['audioWidth'] as int? ?? defaults.audioWidth,
      audioHeight: json['audioHeight'] as int? ?? defaults.audioHeight,
      fileWidth: json['fileWidth'] as int? ?? defaults.fileWidth,
      fileHeight: json['fileHeight'] as int? ?? defaults.fileHeight,
    ).clamp();
  }

  @override
  bool operator ==(Object other) {
    return other is MediaPreviewSizes &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight &&
        other.videoWidth == videoWidth &&
        other.videoHeight == videoHeight &&
        other.audioWidth == audioWidth &&
        other.audioHeight == audioHeight &&
        other.fileWidth == fileWidth &&
        other.fileHeight == fileHeight;
  }

  @override
  int get hashCode => Object.hash(
    imageWidth,
    imageHeight,
    videoWidth,
    videoHeight,
    audioWidth,
    audioHeight,
    fileWidth,
    fileHeight,
  );

  @override
  String toString() {
    return 'MediaPreviewSizes('
        'imageWidth: $imageWidth, '
        'imageHeight: $imageHeight, '
        'videoWidth: $videoWidth, '
        'videoHeight: $videoHeight, '
        'audioWidth: $audioWidth, '
        'audioHeight: $audioHeight, '
        'fileWidth: $fileWidth, '
        'fileHeight: $fileHeight)';
  }
}

MediaPreviewContext markdownMediaPreviewContextForOffset(
  String markdown,
  int offset,
) {
  if (offset < 0 || offset > markdown.length) {
    return MediaPreviewContext.bubble;
  }
  final lines = markdown.split('\n');
  var cursor = 0;
  var tableStart = -1;
  var tableEnd = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final start = cursor;
    final end = start + line.length;
    if (_isMarkdownTableSeparatorLine(line) && i > 0) {
      tableStart = i - 1;
      tableEnd = i;
      for (var j = i + 1; j < lines.length; j++) {
        if (!_looksLikeMarkdownTableRow(lines[j])) break;
        tableEnd = j;
      }
    }
    if (offset >= start && offset <= end) {
      return i >= tableStart && i <= tableEnd
          ? MediaPreviewContext.table
          : MediaPreviewContext.bubble;
    }
    cursor = end + 1;
  }
  return MediaPreviewContext.bubble;
}

bool _looksLikeMarkdownTableRow(String line) {
  final t = line.trim();
  return t.startsWith('|') && t.endsWith('|') && t.split('|').length >= 3;
}

bool _isMarkdownTableSeparatorLine(String line) {
  final t = line.trim();
  if (!_looksLikeMarkdownTableRow(t)) return false;
  final parts = t.split('|');
  for (var i = 1; i < parts.length - 1; i++) {
    final s = parts[i].trim();
    if (s.isEmpty) return false;
    if (!RegExp(r'^:?-{3,}:?$').hasMatch(s)) return false;
  }
  return true;
}
