import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'composer_media_result.dart';

/// 传给库的 `minWidth` / `minHeight`（二者相同）。按 flutter_image_compress 规则，
/// 较短边会缩到不超过此值，较长边按比例变化（可能大于此值）。
/// 1920 与常见「1080p / FHD」宽度一致，比 2048 更省流量，聊天预览通常足够清晰。
const int kChatUploadImageMaxSide = 1920;

/// JPEG 质量（约 0–100）。略降可明显减小体积；75 在聊天场景与体积之间较均衡。
const int kChatUploadJpegQuality = 75;

bool isCompressibleChatImageMime(String mime) {
  if (!mime.startsWith('image/')) return false;
  if (mime == 'image/gif') return false;
  return true;
}

/// 若 [enabled] 为 true，对常见位图做尺寸与 JPEG 质量压缩；失败或未变小则返回原数据。
Future<ComposerMediaResult> applyChatImageCompressionIfEnabled(
  ComposerMediaResult media, {
  required bool enabled,
}) async {
  if (!enabled || media.bytes.isEmpty) return media;
  if (kIsWeb) return media;

  final guessed =
      lookupMimeType(media.fileName, headerBytes: media.bytes) ?? media.mime;
  if (!isCompressibleChatImageMime(guessed)) return media;

  try {
    final compressed = await FlutterImageCompress.compressWithList(
      media.bytes,
      minWidth: kChatUploadImageMaxSide,
      minHeight: kChatUploadImageMaxSide,
      quality: kChatUploadJpegQuality,
      format: CompressFormat.jpeg,
    );
    if (compressed.isEmpty) return media;
    if (compressed.length >= media.bytes.length) return media;

    var name = media.fileName;
    final ext = p.extension(name).toLowerCase();
    if (ext != '.jpg' && ext != '.jpeg') {
      name = '${p.basenameWithoutExtension(name)}.jpg';
    }
    return ComposerMediaResult(
      bytes: compressed,
      fileName: name,
      mime: 'image/jpeg',
      videoDuration: media.videoDuration,
    );
  } catch (_) {
    return media;
  }
}
