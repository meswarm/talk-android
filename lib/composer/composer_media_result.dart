import 'dart:typed_data';

/// 媒体库或自定义相机返回、供 [ChatPage] 统一上传并插入 Markdown。
class ComposerMediaResult {
  const ComposerMediaResult({
    required this.bytes,
    required this.fileName,
    required this.mime,
    this.videoDuration,
  });

  final Uint8List bytes;
  final String fileName;
  final String mime;
  final Duration? videoDuration;
}
