import 'dart:math' show min;

import 'package:flutter/services.dart';

import '../../r2/r2_ref.dart';
import '../r2_markdown_token.dart';

/// `![alt](url)` 且 url **不是** `r2://`（如 `http(s)://`、相对路径）：仍按旧规则用首个 `)` 截断即可。
List<({int start, int end})> _nonR2BangImageLinkSpans(String text) {
  final re = RegExp(r'!\[[^\]]*\]\([^)]+\)');
  final out = <({int start, int end})>[];
  for (final m in re.allMatches(text)) {
    final inner = m.group(0)!;
    final open = inner.indexOf('](r2://');
    if (open >= 0) continue;
    out.add((start: m.start, end: m.end));
  }
  return out;
}

/// When the user deletes any character inside an image token (or the closing `)`),
/// remove the entire `![alt](url)` in one step so long URLs are not deleted
/// character-by-character.
///
/// 对 `[alt](r2://…)` 在推断为音频 / 视频时同样一键删除；对象键中可含 `)`。
class MarkdownImageLinkDeleteFormatter extends TextInputFormatter {
  const MarkdownImageLinkDeleteFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length >= oldValue.text.length) {
      return newValue;
    }

    final oldText = oldValue.text;
    if (oldText.isEmpty) return newValue;

    final range = _singleDeletionRange(oldText, newValue.text);
    if (range == null) return newValue;

    for (final token in parseR2MarkdownTokens(oldText)) {
      if (!token.isImageSyntax &&
          token.kind != R2MediaKind.video &&
          token.kind != R2MediaKind.audio) {
        continue;
      }
      final span = (start: token.start, end: token.end);
      final overlap = range.start < span.end && range.end > span.start;
      if (overlap) {
        final merged = oldText.replaceRange(span.start, span.end, '');
        final cursor = span.start.clamp(0, merged.length);
        return TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(offset: cursor),
          composing: TextRange.empty,
        );
      }
    }
    for (final span in _nonR2BangImageLinkSpans(oldText)) {
      final overlap = range.start < span.end && range.end > span.start;
      if (overlap) {
        final merged = oldText.replaceRange(span.start, span.end, '');
        final cursor = span.start.clamp(0, merged.length);
        return TextEditingValue(
          text: merged,
          selection: TextSelection.collapsed(offset: cursor),
          composing: TextRange.empty,
        );
      }
    }
    return newValue;
  }
}

/// Contiguous deletion range in [oldText] when [newText] is shorter (one region).
({int start, int end})? _singleDeletionRange(String oldText, String newText) {
  if (newText.length > oldText.length) return null;
  final minLen = min(oldText.length, newText.length);
  var l = 0;
  while (l < minLen && oldText[l] == newText[l]) {
    l++;
  }
  var oi = oldText.length - 1;
  var ni = newText.length - 1;
  while (oi >= l && ni >= l && oldText[oi] == newText[ni]) {
    oi--;
    ni--;
  }
  return (start: l, end: oi + 1);
}
