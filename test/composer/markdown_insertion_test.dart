import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/composer/markdown_insertion.dart';

void main() {
  test('inserts snippet at caret with surrounding blank lines', () {
    final next = insertMarkdownSnippet(
      text: 'hello',
      selection: const TextSelection.collapsed(offset: 5),
      snippet: '```dart\nprint("hi");\n```',
    );

    expect(next.text, 'hello\n\n```dart\nprint("hi");\n```');
    expect(next.selection.baseOffset, next.text.length);
  });

  test('replaces selected text with snippet', () {
    final next = insertMarkdownSnippet(
      text: 'hello world',
      selection: const TextSelection(baseOffset: 6, extentOffset: 11),
      snippet: '![cat](r2://bucket/cat.png?mime=image%2Fpng)',
    );

    expect(
      next.text,
      'hello ![cat](r2://bucket/cat.png?mime=image%2Fpng)',
    );
  });

  test('empty document inserts trimmed snippet without extra breaks', () {
    final next = insertMarkdownSnippet(
      text: '',
      selection: const TextSelection.collapsed(offset: 0),
      snippet: '  ```\nhi\n```  ',
    );

    expect(next.text, '```\nhi\n```');
    expect(next.selection.baseOffset, next.text.length);
  });

  test('invalid selection is treated as end of text', () {
    final next = insertMarkdownSnippet(
      text: 'ab',
      selection: const TextSelection.collapsed(offset: 99),
      snippet: 'x',
    );

    expect(next.text, 'abx');
    expect(next.selection.baseOffset, next.text.length);
  });
}
