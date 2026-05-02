import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/widgets/markdown_selection_menu.dart';

void main() {
  test('chat composer does not use Matrix native attachment sending', () {
    final source = File('lib/pages/chat_page.dart').readAsStringSync();

    expect(source, isNot(contains('sendFileEvent')));
    expect(source, isNot(contains('MatrixFile.fromMimeType')));
  });

  test('message bubbles do not render Matrix native attachment widgets', () {
    final source = File('lib/widgets/message_bubble.dart').readAsStringSync();

    expect(source, isNot(contains('EventMediaContent')));
    expect(source, isNot(contains("import 'event_media_content.dart'")));
  });

  test('markdown selection menu keeps copy and copy bubble', () {
    var copiedBubble = false;
    final items = markdownSelectionButtonItems([
      ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () {}),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.share,
        onPressed: () {},
      ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.selectAll,
        onPressed: () {},
      ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.searchWeb,
        onPressed: () {},
      ),
    ], onCopyBubble: () => copiedBubble = true);

    expect(items.map((item) => item.type), [
      ContextMenuButtonType.copy,
      ContextMenuButtonType.selectAll,
    ]);
    expect(items.map((item) => item.label), ['复制', '复制气泡']);

    items.last.onPressed?.call();
    expect(copiedBubble, isTrue);
  });
}
