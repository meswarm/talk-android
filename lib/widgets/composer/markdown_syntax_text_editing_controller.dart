import 'package:flutter/material.dart';

TextStyle _headingStyle(TextStyle base) {
  return base.merge(
    TextStyle(
      fontWeight: FontWeight.w600,
      color: base.color?.withValues(alpha: 0.9),
    ),
  );
}

TextStyle _fenceStyle(TextStyle base) {
  return base.merge(
    TextStyle(
      fontFamily: 'monospace',
      color: base.color?.withValues(alpha: 0.75),
    ),
  );
}

TextStyle _inlineCodeStyle(TextStyle base) {
  return base.merge(
    TextStyle(
      fontFamily: 'monospace',
      backgroundColor: base.color?.withValues(alpha: 0.08),
    ),
  );
}

TextStyle _mediaStyle(TextStyle base) {
  return base.merge(
    TextStyle(color: base.color?.withValues(alpha: 0.65)),
  );
}

TextStyle _linkStyle(TextStyle base) {
  return base.merge(
    TextStyle(
      color: base.color?.withValues(alpha: 0.7),
      decoration: TextDecoration.underline,
      decorationColor: base.color?.withValues(alpha: 0.35),
    ),
  );
}

TextStyle _markerStyle(TextStyle base) {
  return base.merge(
    TextStyle(color: base.color?.withValues(alpha: 0.55)),
  );
}

typedef _StyleFn = TextStyle Function(TextStyle base);

typedef _Hit = ({int start, int end, _StyleFn styleFn});

List<_Hit> _matchesFor(RegExp re, String input, _StyleFn styleFn) {
  return re
      .allMatches(input)
      .map((m) => (start: m.start, end: m.end, styleFn: styleFn))
      .toList();
}

/// Non-overlapping hits: prefer longer match when multiple start at same index.
List<_Hit> _mergeHits(List<_Hit> hits) {
  hits.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return b.end.compareTo(a.end);
  });

  final kept = <_Hit>[];
  for (final h in hits) {
    final overlaps = kept.any(
      (k) => h.start < k.end && h.end > k.start,
    );
    if (overlaps) continue;
    kept.add(h);
  }
  kept.sort((a, b) => a.start.compareTo(b.start));
  return kept;
}

TextSpan buildMarkdownHighlightSpan(String source, TextStyle base) {
  if (source.isEmpty) {
    return TextSpan(style: base, text: '');
  }

  final hits = <_Hit>[
    ..._matchesFor(
      RegExp(r'^\s{0,3}(```|~~~).*$', multiLine: true),
      source,
      _fenceStyle,
    ),
    ..._matchesFor(
      RegExp(r'^\s{0,3}#{1,6}\s.*$', multiLine: true),
      source,
      _headingStyle,
    ),
    ..._matchesFor(
      RegExp(r'^\s{0,3}(>|\- |\* |\d+\. ).*$', multiLine: true),
      source,
      _markerStyle,
    ),
    ..._matchesFor(
      RegExp(r'!\[[^\]]*\]\([^)]+\)'),
      source,
      _mediaStyle,
    ),
    ..._matchesFor(
      RegExp(r'(?<!!)\[[^\]]+\]\([^)]+\)'),
      source,
      _linkStyle,
    ),
    ..._matchesFor(
      RegExp(r'`[^`\n]+`'),
      source,
      _inlineCodeStyle,
    ),
  ];

  final kept = _mergeHits(hits);
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final h in kept) {
    if (h.start > cursor) {
      children.add(TextSpan(text: source.substring(cursor, h.start), style: base));
    }
    children.add(
      TextSpan(
        text: source.substring(h.start, h.end),
        style: h.styleFn(base),
      ),
    );
    cursor = h.end;
  }
  if (cursor < source.length) {
    children.add(TextSpan(text: source.substring(cursor), style: base));
  }

  return TextSpan(style: base, children: children);
}

/// [TextEditingController] that paints lightweight Markdown token highlights.
///
/// Plain text is preserved: [TextSpan.toPlainText] matches [text].
class MarkdownSyntaxTextEditingController extends TextEditingController {
  MarkdownSyntaxTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(!value.composing.isValid || !withComposing || value.isComposingRangeValid);
    final composingRegionOutOfRange =
        !value.isComposingRangeValid || !withComposing;
    if (!composingRegionOutOfRange) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return buildMarkdownHighlightSpan(text, style ?? const TextStyle());
  }
}
