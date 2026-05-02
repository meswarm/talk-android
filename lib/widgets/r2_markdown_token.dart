import '../r2/r2_ref.dart';

class R2MarkdownToken {
  const R2MarkdownToken({
    required this.start,
    required this.end,
    required this.label,
    required this.ref,
    required this.isImageSyntax,
    required this.kind,
  });

  final int start;
  final int end;
  final String label;
  final String ref;
  final bool isImageSyntax;
  final R2MediaKind kind;
}

int? _closingBracketIndex(String text, int openBracketIndex) {
  if (openBracketIndex < 0 || openBracketIndex >= text.length) return null;
  if (text[openBracketIndex] != '[') return null;
  for (var i = openBracketIndex + 1; i < text.length; i++) {
    final ch = text[i];
    if (ch == '\n') return null;
    if (ch == ']') return i;
  }
  return null;
}

int? closingParenIndexForMarkdownDestination(String text, int openParenIndex) {
  if (openParenIndex < 0 || openParenIndex >= text.length) return null;
  if (text[openParenIndex] != '(') return null;
  var depth = 1;
  for (var i = openParenIndex + 1; i < text.length; i++) {
    final ch = text[i];
    if (ch == '\n') return null;
    if (ch == '(') {
      depth++;
      continue;
    }
    if (ch != ')') continue;
    depth--;
    if (depth == 0) return i;
  }
  return null;
}

List<R2MarkdownToken> parseR2MarkdownTokens(String text) {
  final out = <R2MarkdownToken>[];
  for (var i = 0; i < text.length; i++) {
    final isImageSyntax = text[i] == '!';
    final openBracketIndex = isImageSyntax ? i + 1 : i;
    if (openBracketIndex >= text.length || text[openBracketIndex] != '[') {
      continue;
    }
    final closeBracketIndex = _closingBracketIndex(text, openBracketIndex);
    if (closeBracketIndex == null) continue;
    final openParenIndex = closeBracketIndex + 1;
    if (openParenIndex >= text.length || text[openParenIndex] != '(') continue;
    final closeParenIndex = closingParenIndexForMarkdownDestination(
      text,
      openParenIndex,
    );
    if (closeParenIndex == null) continue;

    final ref = text.substring(openParenIndex + 1, closeParenIndex);
    if (parseR2Ref(ref) == null) {
      i = closeParenIndex;
      continue;
    }

    final start = isImageSyntax ? i : openBracketIndex;
    out.add(
      R2MarkdownToken(
        start: start,
        end: closeParenIndex + 1,
        label: text.substring(openBracketIndex + 1, closeBracketIndex),
        ref: ref,
        isImageSyntax: isImageSyntax,
        kind: inferR2MediaKind(ref),
      ),
    );
    i = closeParenIndex;
  }
  return out;
}

String rewriteR2BracketLinksToPreviewCardsMarkdown(String markdown) {
  final tokens = parseR2MarkdownTokens(markdown);
  if (tokens.isEmpty) return markdown;

  final out = StringBuffer();
  var cursor = 0;
  for (final token in tokens) {
    out.write(markdown.substring(cursor, token.start));
    if (token.isImageSyntax) {
      out.write(markdown.substring(token.start, token.end));
    } else {
      out.write('![${token.label}](${token.ref})');
    }
    cursor = token.end;
  }
  out.write(markdown.substring(cursor));
  return out.toString();
}
