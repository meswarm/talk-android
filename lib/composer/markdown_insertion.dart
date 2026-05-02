import 'package:flutter/services.dart';

bool _isBlockSnippet(String trimmedSnippet) {
  if (trimmedSnippet.contains('\n')) return true;
  final firstLine = trimmedSnippet.split('\n').first;
  return RegExp(r'^\s*(```|~~~)').hasMatch(firstLine);
}

/// Inserts [snippet] into [text] at [selection], returning the next editing value.
///
/// Block-like snippets (fences, multi-line blocks) get blank-line padding when
/// joined to non-empty text before/after. Single-line snippets replace inline.
TextEditingValue insertMarkdownSnippet({
  required String text,
  required TextSelection selection,
  required String snippet,
}) {
  final len = text.length;
  var sel = selection;
  if (!sel.isValid ||
      sel.start < 0 ||
      sel.end < 0 ||
      sel.start > len ||
      sel.end > len ||
      sel.start > sel.end) {
    sel = TextSelection.collapsed(offset: len);
  }

  final start = sel.start;
  final end = sel.end;
  final beforeRaw = text.substring(0, start);
  final afterRaw = text.substring(end);
  final trimmedSnippet = snippet.trim();

  if (_isBlockSnippet(trimmedSnippet)) {
    final beforeTrim = beforeRaw.replaceAll(RegExp(r'\s+$'), '');
    final afterTrim = afterRaw.replaceAll(RegExp(r'^\s+'), '');
    final needsLeading = beforeTrim.isNotEmpty;
    final needsTrailing = afterTrim.isNotEmpty;

    final buffer = StringBuffer();
    if (beforeTrim.isNotEmpty) buffer.write(beforeTrim);
    if (needsLeading) buffer.write('\n\n');
    buffer.write(trimmedSnippet);
    if (needsTrailing) buffer.write('\n\n');
    if (afterTrim.isNotEmpty) buffer.write(afterTrim);

    final newText = buffer.toString();
    final insertStart = beforeTrim.isEmpty
        ? 0
        : beforeTrim.length + (needsLeading ? 2 : 0);
    final caret = insertStart + trimmedSnippet.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: caret.clamp(0, newText.length),
      ),
    );
  }

  final newText = beforeRaw + trimmedSnippet + afterRaw;
  final caret = beforeRaw.length + trimmedSnippet.length;
  return TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(
      offset: caret.clamp(0, newText.length),
    ),
  );
}
