import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/widgets/composer/markdown_source_editor.dart';
import 'package:talk/widgets/composer/markdown_syntax_text_editing_controller.dart';

void main() {
  testWidgets('source editor shows multiline text field with bottom safe padding',
      (tester) async {
    final controller = MarkdownSyntaxTextEditingController(text: '# hi');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownSourceEditor(
            controller: controller,
            focusNode: FocusNode(),
            isDark: false,
            bottomInset: 8,
            rightInset: 56,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final padding = field.decoration!.contentPadding! as EdgeInsets;

    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, '# hi');
    expect(padding.right, greaterThanOrEqualTo(12 + 56));
    expect(padding.bottom, greaterThanOrEqualTo(12 + 8));
  });

  testWidgets('source editor does not mutate image markdown text', (tester) async {
    final controller =
        MarkdownSyntaxTextEditingController(text: '![a](http://x)');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownSourceEditor(
            controller: controller,
            focusNode: FocusNode(),
            isDark: false,
            bottomInset: 8,
            rightInset: 56,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(controller.text, '![a](http://x)');
  });

  testWidgets('source editor normalizes empty selection when focused',
      (tester) async {
    final controller = MarkdownSyntaxTextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownSourceEditor(
            controller: controller,
            focusNode: focusNode,
            isDark: false,
            bottomInset: 8,
            rightInset: 56,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(controller.selection.isValid, isFalse);

    focusNode.requestFocus();
    await tester.pump();

    expect(controller.selection.isValid, isTrue);
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 0);
  });
}
