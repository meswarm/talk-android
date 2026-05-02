import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/widgets/composer/markdown_syntax_text_editing_controller.dart';

List<TextSpan> flattenTextSpans(TextSpan span) {
  final out = <TextSpan>[];
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text != null && node.text!.isNotEmpty) {
        out.add(TextSpan(style: node.style, text: node.text));
      }
      if (node.children != null) {
        for (final child in node.children!) {
          walk(child);
        }
      }
    }
  }

  walk(span);
  return out;
}

void main() {
  testWidgets('highlights image and video markdown as media tokens', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final controller = MarkdownSyntaxTextEditingController()
      ..text = '![cat](r2://bucket/cat.png?mime=image%2Fpng)\n'
          '![clip.mp4（视频）](r2://bucket/clip.mp4?mime=video%2Fmp4)';

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(color: Colors.black),
      withComposing: false,
    );

    expect(span.toPlainText(), controller.text);
    expect(
      flattenTextSpans(span).where((s) => s.text!.contains('![')).length,
      2,
    );
    expect(
      flattenTextSpans(span).where((s) => s.text!.contains('[clip.mp4')).length,
      1,
    );
  });
}
