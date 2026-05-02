// `r2://` reference parsing (parity with `talkweb/src/r2/r2Ref.ts`).

/// 从对象键路径 / 扩展名推断的媒体类别（不读取 `?mime=`；新消息 ref 不再附带 mime 查询参数）。
enum R2MediaKind { image, video, audio, file, unknown }

const _r2ImageExts = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
};
const _r2VideoExts = {
  'mp4',
  'mov',
  'webm',
  'm4v',
};
const _r2AudioExts = {
  'mp3',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'opus',
  'flac',
  'weba',
};

String _objectKeyExtension(String objectKey) {
  final slash = objectKey.lastIndexOf('/');
  final name = slash < 0 ? objectKey : objectKey.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

/// 仅依据 [objectKey]：先匹配路径段 `imgs` / `videos` / `audios` / `files`，再匹配扩展名。
R2MediaKind inferR2MediaKindFromObjectKey(String objectKey) {
  for (final seg in objectKey.split('/')) {
    switch (seg) {
      case 'imgs':
        return R2MediaKind.image;
      case 'videos':
        return R2MediaKind.video;
      case 'audios':
        return R2MediaKind.audio;
      case 'files':
        return R2MediaKind.file;
    }
  }
  final ext = _objectKeyExtension(objectKey);
  if (_r2ImageExts.contains(ext)) return R2MediaKind.image;
  if (_r2VideoExts.contains(ext)) return R2MediaKind.video;
  if (_r2AudioExts.contains(ext)) return R2MediaKind.audio;
  return R2MediaKind.unknown;
}

/// 解析 [ref] 后推断媒体类型；解析失败则为 [R2MediaKind.unknown]。
R2MediaKind inferR2MediaKind(String ref) {
  final parsed = parseR2Ref(ref);
  if (parsed == null) return R2MediaKind.unknown;
  return inferR2MediaKindFromObjectKey(parsed.objectKey);
}

class ParsedR2Ref {
  final String bucket;
  final String objectKey;
  final String? mimeHint;

  const ParsedR2Ref({
    required this.bucket,
    required this.objectKey,
    this.mimeHint,
  });
}

const _r2Scheme = 'r2://';

ParsedR2Ref? parseR2Ref(String? raw) {
  if (raw == null) return null;
  var t = raw.trim();
  if (t.isEmpty) return null;
  if (!t.toLowerCase().startsWith(_r2Scheme)) return null;

  var pathPart = t;
  String? mimeHint;
  final q = t.indexOf('?');
  if (q >= 0) {
    pathPart = t.substring(0, q);
    final params = Uri.splitQueryString(t.substring(q + 1));
    final m = params['mime'];
    if (m != null && m.isNotEmpty) mimeHint = m;
  }
  if (!pathPart.toLowerCase().startsWith(_r2Scheme)) return null;
  final rest = pathPart.substring(_r2Scheme.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) return null;
  final bucket = rest.substring(0, slash);
  final objectKey = rest.substring(slash + 1);
  if (bucket.isEmpty || objectKey.isEmpty) return null;
  if (bucket.contains('/')) return null;
  return ParsedR2Ref(bucket: bucket, objectKey: objectKey, mimeHint: mimeHint);
}

String r2RefWithoutQuery(String ref) {
  final i = ref.indexOf('?');
  return i >= 0 ? ref.substring(0, i) : ref;
}

/// 构建 `r2://bucket/objectKey`。第三参 [mimeHint] 已废弃且会被忽略（不再写入 `?mime=`）。
String buildR2Ref(String bucket, String objectKey, [String? mimeHint]) {
  final b = bucket.trim();
  final k = objectKey.replaceFirst(RegExp(r'^/+'), '');
  if (b.isEmpty || k.isEmpty) {
    throw ArgumentError('Invalid r2 ref parts');
  }
  return '$_r2Scheme$b/$k';
}

String sanitizeFilenameForKey(String name) {
  var base = name.replaceAll(RegExp(r'[/\\]'), '_').trim();
  if (base.isEmpty) base = 'file';
  final cleaned = base.replaceAll(RegExp(r'[^\w.\-()+]+'), '_');
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}

String buildAttachmentObjectKey(String fileName) {
  final safe = sanitizeFilenameForKey(fileName);
  return 'attachments/${DateTime.now().millisecondsSinceEpoch}-$safe';
}

/// 按 MIME 将上传归类到房间下的子目录名。
String attachmentDirFromMime(String mime) {
  final m = mime.trim().toLowerCase();
  if (m.startsWith('image/')) return 'imgs';
  if (m.startsWith('video/')) return 'videos';
  if (m.startsWith('audio/')) return 'audios';
  return 'files';
}

/// 房间前缀下的对象键：`{prefix}/{imgs|videos|audios|files}/{ts}-{safeName}`。
///
/// [roomPrefix] 须已通过 [validateRoomR2Prefix] 得到规范化字符串。
String buildRoomAttachmentObjectKey({
  required String roomPrefix,
  required String fileName,
  required String mime,
}) {
  final dir = attachmentDirFromMime(mime);
  final safe = sanitizeFilenameForKey(fileName);
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '$roomPrefix/$dir/$ts-$safe';
}

/// 将 `[label](r2://…)` 且推断为音频的链接改为 `![label](r2://…)`，供 Markdown 内联音频控件渲染。
String rewriteR2AudioBracketLinksToImageMarkdown(String markdown) {
  return markdown.replaceAllMapped(
    RegExp(r'(?<!\!)\[([^\]]+)\]\((r2://[^)\s]+)\)'),
    (Match m) {
      final ref = m.group(2)!;
      if (inferR2MediaKind(ref) != R2MediaKind.audio) return m.group(0)!;
      return '![${m.group(1)!}]($ref)';
    },
  );
}

/// Markdown snippet after upload (parity with `talkweb/src/matrix/insertMediaMarkdown.ts`).
String r2MarkdownSnippet(String fileName, String mime, String ref) {
  var alt = fileName
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (alt.isEmpty) alt = 'file';
  if (mime.startsWith('image/')) return '![$alt]($ref)';
  // 与图片相同使用 `![alt](url)`，便于一键删除并与 ImgConfig 统一渲染为媒体块。
  if (mime.startsWith('video/')) return '![$alt（视频）]($ref)';
  if (mime.startsWith('audio/')) return '![$alt（音频）]($ref)';
  return '[$alt]($ref)';
}
