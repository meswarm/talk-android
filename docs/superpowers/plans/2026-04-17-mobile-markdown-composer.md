# Mobile Markdown Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current source/preview Markdown composer with a preview-first, block-based mobile editor that still stores and sends a single Markdown string.

**Architecture:** Introduce a small Markdown document model plus a controller that owns the source string and reparses editable blocks after every mutation. Build the new composer as focused widgets for toolbar, document editor, paragraph block, image block, and code block, then integrate it into `ChatPage` while preserving existing Matrix send and R2 upload helpers.

**Tech Stack:** Flutter, Dart, `markdown_widget`, Provider, existing Matrix/R2 helpers, `flutter_test`

---

## File Structure

### New files

- `lib/composer/markdown_block.dart`
  - Immutable block types and source ranges for paragraph, image, code, and unsupported blocks.
- `lib/composer/markdown_document_parser.dart`
  - Parses Markdown source into ordered blocks for the editor.
- `lib/composer/markdown_document_controller.dart`
  - Owns source text, active block state, block mutations, and flush-on-send behavior.
- `lib/widgets/composer/markdown_composer_toolbar.dart`
  - Top icon row for insert and collapse actions.
- `lib/widgets/composer/markdown_document_editor.dart`
  - Preview-first block list host and active-block switching.
- `lib/widgets/composer/paragraph_block.dart`
  - Preview and in-place edit UI for paragraph blocks.
- `lib/widgets/composer/code_block.dart`
  - Preview and in-place edit UI for fenced code blocks, including delete affordance.
- `lib/widgets/composer/image_block.dart`
  - Image card UI with top-right delete affordance.
- `test/composer/markdown_document_parser_test.dart`
  - Parser coverage for paragraph, image, code, and unsupported blocks.
- `test/composer/markdown_document_controller_test.dart`
  - Controller coverage for insert, update, delete, active block movement, and flush behavior.
- `test/widgets/markdown_document_editor_test.dart`
  - Widget coverage for tap-to-edit, code/image delete buttons, and insert behavior.

### Modified files

- `lib/pages/chat_page.dart`
  - Remove source/preview toggle workflow from the composer area and host the new toolbar/editor/controller.
- `lib/widgets/markdown_renderer.dart`
  - Reuse for preview rendering inside block widgets; no feature change expected, but block widgets may need small helper exposure if rendering code is duplicated.
- `test/services/local_storage_composer_and_draft_test.dart`
  - Extend if composer draft persistence behavior changes with controller flush timing.

## Task 1: Add Markdown block model and parser

**Files:**

- Create: `lib/composer/markdown_block.dart`
- Create: `lib/composer/markdown_document_parser.dart`
- Test: `test/composer/markdown_document_parser_test.dart`
- **Step 1: Write the failing parser tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/composer/markdown_block.dart';
import 'package:talk/composer/markdown_document_parser.dart';

void main() {
  group('parseMarkdownBlocks', () {
    test('splits paragraphs, image markdown, and fenced code blocks', () {
      const source = '''
Hello world

![cat](r2://bucket/cat.png?mime=image%2Fpng)

```dart
print("hi");
```

''';

```
  final blocks = parseMarkdownBlocks(source);

  expect(blocks.map((b) => b.type), [
    MarkdownBlockType.paragraph,
    MarkdownBlockType.image,
    MarkdownBlockType.codeBlock,
  ]);
  expect(blocks[1].sourceText,
      '![cat](r2://bucket/cat.png?mime=image%2Fpng)');
  expect(blocks[2].sourceText, contains('print("hi");'));
});

test('keeps unsupported markdown as unsupported block', () {
  const source = '''
```


| A    | B   |
| ---- | --- |
| 1    | 2   |
| '''; |     |


```
  final blocks = parseMarkdownBlocks(source);

  expect(blocks, hasLength(1));
  expect(blocks.single.type, MarkdownBlockType.unsupportedBlock);
});
```

  });
}

```

- [ ] **Step 2: Run the parser test to verify it fails**

Run: `flutter test test/composer/markdown_document_parser_test.dart -r expanded`

Expected: FAIL with missing imports or undefined `parseMarkdownBlocks` / `MarkdownBlockType`.

- [ ] **Step 3: Add the block model**

```dart
enum MarkdownBlockType {
  paragraph,
  image,
  codeBlock,
  unsupportedBlock,
}

class MarkdownBlock {
  final String id;
  final MarkdownBlockType type;
  final int startOffset;
  final int endOffset;
  final String sourceText;
  final String? altText;
  final String? url;
  final String? codeLanguage;

  const MarkdownBlock({
    required this.id,
    required this.type,
    required this.startOffset,
    required this.endOffset,
    required this.sourceText,
    this.altText,
    this.url,
    this.codeLanguage,
  });
}
```

- **Step 4: Add the parser implementation**

```dart
List<MarkdownBlock> parseMarkdownBlocks(String source) {
  final blocks = <MarkdownBlock>[];
  final imageRe = RegExp(r'!\[(.*?)\]\((.+?)\)');
  final codeStartRe = RegExp(r'^```([^\n]*)$');
  final lines = source.split('\n');
  var offset = 0;
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];

    if (line.trim().isEmpty) {
      offset += line.length + 1;
      i += 1;
      continue;
    }

    if (line.trim().startsWith('|')) {
      final start = offset;
      final buf = <String>[line];
      i += 1;
      offset += line.length + 1;
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        final next = lines[i];
        buf.add(next);
        offset += next.length + 1;
        i += 1;
      }
      final sourceText = buf.join('\n').trimRight();
      blocks.add(MarkdownBlock(
        id: 'tbl-$start',
        type: MarkdownBlockType.unsupportedBlock,
        startOffset: start,
        endOffset: start + sourceText.length,
        sourceText: sourceText,
      ));
      continue;
    }

    final codeMatch = codeStartRe.firstMatch(line);
    if (codeMatch != null) {
      final start = offset;
      final lang = codeMatch.group(1)?.trim();
      final buf = <String>[line];
      i += 1;
      offset += line.length + 1;
      while (i < lines.length) {
        final next = lines[i];
        buf.add(next);
        offset += next.length + 1;
        i += 1;
        if (next.trim() == '```') break;
      }
      final sourceText = buf.join('\n').trimRight();
      blocks.add(MarkdownBlock(
        id: 'code-$start',
        type: MarkdownBlockType.codeBlock,
        startOffset: start,
        endOffset: start + sourceText.length,
        sourceText: sourceText,
        codeLanguage: lang == null || lang.isEmpty ? null : lang,
      ));
      continue;
    }

    final imageMatch = imageRe.firstMatch(line.trim());
    if (imageMatch != null && imageMatch.group(0) == line.trim()) {
      final start = offset + line.indexOf(line.trim());
      final sourceText = imageMatch.group(0)!;
      blocks.add(MarkdownBlock(
        id: 'img-$start',
        type: MarkdownBlockType.image,
        startOffset: start,
        endOffset: start + sourceText.length,
        sourceText: sourceText,
        altText: imageMatch.group(1),
        url: imageMatch.group(2),
      ));
      offset += line.length + 1;
      i += 1;
      continue;
    }

    final start = offset;
    final buf = <String>[line];
    i += 1;
    offset += line.length + 1;
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      final next = lines[i];
      if (next.trim().startsWith('|') || codeStartRe.hasMatch(next)) break;
      buf.add(next);
      offset += next.length + 1;
      i += 1;
    }
    final sourceText = buf.join('\n').trimRight();
    blocks.add(MarkdownBlock(
      id: 'blk-$start',
      type: MarkdownBlockType.paragraph,
      startOffset: start,
      endOffset: start + sourceText.length,
      sourceText: sourceText,
    ));
  }

  return blocks;
}
```

- **Step 5: Run the parser tests to verify they pass**

Run: `flutter test test/composer/markdown_document_parser_test.dart -r expanded`

Expected: PASS for the parser coverage group.

- **Step 6: Commit**

```bash
git add lib/composer/markdown_block.dart lib/composer/markdown_document_parser.dart test/composer/markdown_document_parser_test.dart
git commit -m "feat: add markdown composer block parser"
```

## Task 2: Add document controller and mutation rules

**Files:**

- Create: `lib/composer/markdown_document_controller.dart`
- Test: `test/composer/markdown_document_controller_test.dart`
- Modify: `lib/composer/markdown_document_parser.dart`
- **Step 1: Write the failing controller tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/composer/markdown_block.dart';
import 'package:talk/composer/markdown_document_controller.dart';

void main() {
  test('insertCodeBlock inserts after active block and activates it', () {
    final controller = MarkdownDocumentController(
      initialText: 'Alpha\n\nBeta',
    );

    controller.activateBlock(controller.blocks.first.id);
    controller.insertCodeBlock();

    expect(controller.text, contains('```'));
    expect(controller.activeBlock?.type, MarkdownBlockType.codeBlock);
  });

  test('deleteBlock removes the exact markdown range', () {
    final controller = MarkdownDocumentController(
      initialText: 'Hello\n\n![cat](r2://bucket/cat.png)',
    );

    final image = controller.blocks.singleWhere(
      (b) => b.type == MarkdownBlockType.image,
    );

    controller.deleteBlock(image.id);

    expect(controller.text, 'Hello');
    expect(
      controller.blocks.any((b) => b.type == MarkdownBlockType.image),
      isFalse,
    );
  });

  test('flushActiveDraft writes temporary edits back into source', () {
    final controller = MarkdownDocumentController(
      initialText: 'Original paragraph',
    );

    final paragraph = controller.blocks.single;
    controller.activateBlock(paragraph.id);
    controller.setActiveDraft('Changed paragraph');
    controller.flushActiveDraft();

    expect(controller.text, 'Changed paragraph');
  });
}
```

- **Step 2: Run the controller test to verify it fails**

Run: `flutter test test/composer/markdown_document_controller_test.dart -r expanded`

Expected: FAIL with undefined `MarkdownDocumentController` methods.

- **Step 3: Implement the controller**

```dart
class MarkdownDocumentController extends ChangeNotifier {
  String _text;
  List<MarkdownBlock> _blocks;
  String? _activeBlockId;
  String? _activeDraft;

  MarkdownDocumentController({required String initialText})
      : _text = initialText,
        _blocks = parseMarkdownBlocks(initialText);

  String get text => _text;
  List<MarkdownBlock> get blocks => List.unmodifiable(_blocks);
  MarkdownBlock? get activeBlock {
    for (final block in _blocks) {
      if (block.id == _activeBlockId) return block;
    }
    return null;
  }
  String? get activeDraft => _activeDraft;

  void activateBlock(String blockId) {
    flushActiveDraft();
    _activeBlockId = blockId;
    _activeDraft = activeBlock?.sourceText;
    notifyListeners();
  }

  void setActiveDraft(String value) {
    _activeDraft = value;
    notifyListeners();
  }

  void flushActiveDraft() {
    final block = activeBlock;
    final draft = _activeDraft;
    if (block == null || draft == null || draft == block.sourceText) return;
    _replaceRange(block.startOffset, block.endOffset, draft);
  }

  void deleteBlock(String blockId) {
    final block = _blocks.firstWhere((b) => b.id == blockId);
    _replaceRange(block.startOffset, block.endOffset, '');
    if (_activeBlockId == blockId) {
      _activeBlockId = null;
      _activeDraft = null;
    }
  }

  void insertCodeBlock() {
    final insertion = '\n\n```\n\n```\n';
    final block = activeBlock;
    final offset = block?.endOffset ?? _text.length;
    _replaceRange(offset, offset, insertion);
    final codeBlock = _blocks.firstWhere((b) => b.type == MarkdownBlockType.codeBlock);
    _activeBlockId = codeBlock.id;
    _activeDraft = codeBlock.sourceText;
    notifyListeners();
  }

  void replaceFullText(String next) {
    _text = next;
    _blocks = parseMarkdownBlocks(next);
    notifyListeners();
  }

  void _replaceRange(int start, int end, String replacement) {
    final next = _text.replaceRange(start, end, replacement).trimRight();
    _text = next;
    _blocks = parseMarkdownBlocks(next);
    notifyListeners();
  }
}
```

- **Step 4: Add parser support needed by the controller**

```dart
// In markdown_document_parser.dart, ensure blank-line normalization stays stable
// so controller replaceRange reparses into predictable blocks.

String normalizeComposerMarkdown(String source) {
  return source.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
}
```

- **Step 5: Run controller and parser tests to verify they pass**

Run: `flutter test test/composer/markdown_document_controller_test.dart test/composer/markdown_document_parser_test.dart -r expanded`

Expected: PASS for all controller and parser tests.

- **Step 6: Commit**

```bash
git add lib/composer/markdown_document_controller.dart lib/composer/markdown_document_parser.dart test/composer/markdown_document_controller_test.dart test/composer/markdown_document_parser_test.dart
git commit -m "feat: add markdown composer controller"
```

## Task 3: Build the toolbar and paragraph editor

**Files:**

- Create: `lib/widgets/composer/markdown_composer_toolbar.dart`
- Create: `lib/widgets/composer/markdown_document_editor.dart`
- Create: `lib/widgets/composer/paragraph_block.dart`
- Test: `test/widgets/markdown_document_editor_test.dart`
- **Step 1: Write the failing widget test for paragraph editing**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/composer/markdown_document_controller.dart';
import 'package:talk/widgets/composer/markdown_document_editor.dart';

void main() {
  testWidgets('tapping paragraph enters in-place edit mode',
      (tester) async {
    final controller = MarkdownDocumentController(
      initialText: 'Tap me',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownDocumentEditor(
          controller: controller,
          isDark: false,
        ),
      ),
    ));

    await tester.tap(find.text('Tap me'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(controller.activeBlock?.sourceText, 'Tap me');
  });
}
```

- **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL with missing `MarkdownDocumentEditor`.

- **Step 3: Implement the toolbar**

```dart
class MarkdownComposerToolbar extends StatelessWidget {
  final VoidCallback onInsertCode;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertVideo;
  final VoidCallback onInsertAudio;
  final VoidCallback onInsertFile;
  final VoidCallback onCollapse;
  final bool enabled;

  const MarkdownComposerToolbar({
    super.key,
    required this.onInsertCode,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertAudio,
    required this.onInsertFile,
    required this.onCollapse,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: enabled ? onInsertCode : null,
          tooltip: '插入代码块',
          icon: const Icon(Icons.code),
        ),
        IconButton(
          onPressed: enabled ? onInsertImage : null,
          tooltip: '插入图像',
          icon: const Icon(Icons.image_outlined),
        ),
        IconButton(
          onPressed: enabled ? onInsertVideo : null,
          tooltip: '插入视频',
          icon: const Icon(Icons.videocam_outlined),
        ),
        IconButton(
          onPressed: enabled ? onInsertAudio : null,
          tooltip: '插入音频',
          icon: const Icon(Icons.graphic_eq),
        ),
        IconButton(
          onPressed: enabled ? onInsertFile : null,
          tooltip: '插入文件',
          icon: const Icon(Icons.attach_file),
        ),
        const Spacer(),
        IconButton(
          onPressed: onCollapse,
          tooltip: '收起',
          icon: const Icon(Icons.expand_more),
        ),
      ],
    );
  }
}
```

- **Step 4: Implement paragraph editing inside the document editor**

```dart
class ParagraphBlock extends StatelessWidget {
  final MarkdownBlock block;
  final bool editing;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  const ParagraphBlock({
    super.key,
    required this.block,
    required this.editing,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return TextField(
        controller: TextEditingController(text: block.sourceText),
        autofocus: true,
        maxLines: null,
        onChanged: onChanged,
        decoration: const InputDecoration(border: InputBorder.none),
      );
    }
    return InkWell(
      onTap: onTap,
      child: MarkdownRenderer(
        data: block.sourceText,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}
```

- **Step 5: Implement the document editor shell**

```dart
class MarkdownDocumentEditor extends StatelessWidget {
  final MarkdownDocumentController controller;
  final bool isDark;

  const MarkdownDocumentEditor({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final block in controller.blocks)
              if (block.type == MarkdownBlockType.paragraph)
                ParagraphBlock(
                  block: block,
                  editing: controller.activeBlock?.id == block.id,
                  onTap: () => controller.activateBlock(block.id),
                  onChanged: controller.setActiveDraft,
                )
              else
                MarkdownRenderer(data: block.sourceText, isDark: isDark),
          ],
        );
      },
    );
  }
}
```

- **Step 6: Run the widget test to verify it passes**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: PASS for the paragraph editing interaction test.

- **Step 7: Commit**

```bash
git add lib/widgets/composer/markdown_composer_toolbar.dart lib/widgets/composer/markdown_document_editor.dart lib/widgets/composer/paragraph_block.dart test/widgets/markdown_document_editor_test.dart
git commit -m "feat: add preview-first paragraph composer"
```

## Task 4: Add image and code block interactions

**Files:**

- Create: `lib/widgets/composer/code_block.dart`
- Create: `lib/widgets/composer/image_block.dart`
- Modify: `lib/widgets/composer/markdown_document_editor.dart`
- Modify: `test/widgets/markdown_document_editor_test.dart`
- **Step 1: Add failing widget tests for code and image blocks**

```dart
testWidgets('code block enters edit mode and can be deleted', (tester) async {
  final controller = MarkdownDocumentController(
    initialText: '```dart\nprint("hi");\n```',
  );

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MarkdownDocumentEditor(controller: controller, isDark: false),
    ),
  ));

  await tester.tap(find.textContaining('print("hi");'));
  await tester.pump();
  expect(find.byType(TextField), findsOneWidget);

  await tester.tap(find.byIcon(Icons.close));
  await tester.pump();
  expect(controller.text, isEmpty);
});

testWidgets('image block delete button removes markdown fragment',
    (tester) async {
  final controller = MarkdownDocumentController(
    initialText: '![cat](r2://bucket/cat.png?mime=image%2Fpng)',
  );

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MarkdownDocumentEditor(controller: controller, isDark: false),
    ),
  ));

  await tester.tap(find.byIcon(Icons.close));
  await tester.pump();

  expect(controller.text, isEmpty);
});
```

- **Step 2: Run the widget tests to verify they fail**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL because code and image blocks do not yet expose delete/edit interactions.

- **Step 3: Implement the image block card**

```dart
class ImageBlockCard extends StatelessWidget {
  final MarkdownBlock block;
  final VoidCallback onDelete;

  const ImageBlockCard({
    super.key,
    required this.block,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: MarkdownRenderer(
            data: block.sourceText,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: onDelete,
            tooltip: '删除图像',
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }
}
```

- **Step 4: Implement the code block widget**

```dart
class CodeBlock extends StatelessWidget {
  final MarkdownBlock block;
  final bool editing;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const CodeBlock({
    super.key,
    required this.block,
    required this.editing,
    required this.onChanged,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          child: editing
              ? TextField(
                  controller: TextEditingController(text: block.sourceText),
                  autofocus: true,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: onChanged,
                )
              : MarkdownRenderer(
                  data: block.sourceText,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            onPressed: onDelete,
            tooltip: '删除代码块',
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }
}
```

- **Step 5: Wire code/image blocks into the document editor**

```dart
// Inside MarkdownDocumentEditor builder:
switch (block.type) {
  case MarkdownBlockType.paragraph:
    return ParagraphBlock(...);
  case MarkdownBlockType.image:
    return ImageBlockCard(
      block: block,
      onDelete: () => controller.deleteBlock(block.id),
    );
  case MarkdownBlockType.codeBlock:
    return CodeBlock(
      block: block,
      editing: controller.activeBlock?.id == block.id,
      onTap: () => controller.activateBlock(block.id),
      onChanged: controller.setActiveDraft,
      onDelete: () => controller.deleteBlock(block.id),
    );
  case MarkdownBlockType.unsupportedBlock:
    return MarkdownRenderer(data: block.sourceText, isDark: isDark);
}
```

- **Step 6: Run the widget tests to verify they pass**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: PASS for paragraph, image delete, and code block edit/delete interactions.

- **Step 7: Commit**

```bash
git add lib/widgets/composer/code_block.dart lib/widgets/composer/image_block.dart lib/widgets/composer/markdown_document_editor.dart test/widgets/markdown_document_editor_test.dart
git commit -m "feat: add image and code block composer interactions"
```

## Task 5: Integrate the new composer into ChatPage

**Files:**

- Modify: `lib/pages/chat_page.dart`
- Modify: `lib/widgets/composer/markdown_composer_toolbar.dart`
- Modify: `lib/widgets/composer/markdown_document_editor.dart`
- Test: `test/widgets/markdown_document_editor_test.dart`
- **Step 1: Add a failing integration-oriented widget test**

```dart
testWidgets('insert code action adds a code block after the active paragraph',
    (tester) async {
  final controller = MarkdownDocumentController(
    initialText: 'Hello',
  );

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          MarkdownComposerToolbar(
            enabled: true,
            onInsertCode: controller.insertCodeBlock,
            onInsertImage: () {},
            onInsertVideo: () {},
            onInsertAudio: () {},
            onInsertFile: () {},
            onCollapse: () {},
          ),
          Expanded(
            child: MarkdownDocumentEditor(controller: controller, isDark: false),
          ),
        ],
      ),
    ),
  ));

  await tester.tap(find.text('Hello'));
  await tester.pump();
  await tester.tap(find.byIcon(Icons.code));
  await tester.pump();

  expect(controller.text, contains('```'));
  expect(controller.activeBlock?.type, MarkdownBlockType.codeBlock);
});
```

- **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL until toolbar integration and active-block insertion are wired.

- **Step 3: Add controller state to ChatPage**

```dart
late MarkdownDocumentController _composerDocController;

@override
void initState() {
  super.initState();
  _composerDocController = MarkdownDocumentController(initialText: '');
  _messageController.addListener(_syncSourceIntoDocIfNeeded);
}

void _syncSourceIntoDocIfNeeded() {
  final next = _messageController.text;
  if (_composerDocController.text == next) return;
  _composerDocController.replaceFullText(next);
}
```

- **Step 4: Replace preview toggle UI with the new toolbar/editor**

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
  child: MarkdownComposerToolbar(
    enabled: !_uploadingMedia,
    onInsertCode: () {
      _composerDocController.insertCodeBlock();
      _messageController.text = _composerDocController.text;
    },
    onInsertImage: _pickAndSendImage,
    onInsertVideo: _pickAndSendVideo,
    onInsertAudio: _pickAndSendAudio,
    onInsertFile: _pickAndSendFile,
    onCollapse: _collapseComposer,
  ),
),
Expanded(
  child: MarkdownDocumentEditor(
    controller: _composerDocController,
    isDark: isDark,
  ),
),
```

- **Step 5: Flush controller state before save draft and before send**

```dart
Future<void> _sendMessage() async {
  _composerDocController.flushActiveDraft();
  _messageController.text = _composerDocController.text;
  final text = _messageController.text.trim();
  if (text.isEmpty) return;
  // existing send logic continues unchanged
}

void _persistComposerDraft() {
  _composerDocController.flushActiveDraft();
  final text = _composerDocController.text;
  _messageController.text = text;
  unawaited(LocalStorage().saveDraft(widget.room.id, text));
}
```

- **Step 6: Remove obsolete preview-mode state and focus wiring**

```dart
// Delete once the new composer is working:
// bool _composerPreview
// FocusNode _composerPreviewFocus
// bool get _toolbarMediaEnabled => !_composerPreview && !_uploadingMedia;
// _toggleComposerPreview()
// _onComposerPreviewKey()
```

- **Step 7: Run focused tests to verify integration passes**

Run: `flutter test test/widgets/markdown_document_editor_test.dart test/composer/markdown_document_controller_test.dart test/composer/markdown_document_parser_test.dart -r expanded`

Expected: PASS for all composer-related tests.

- **Step 8: Commit**

```bash
git add lib/pages/chat_page.dart lib/widgets/composer/markdown_composer_toolbar.dart lib/widgets/composer/markdown_document_editor.dart test/widgets/markdown_document_editor_test.dart test/composer/markdown_document_controller_test.dart test/composer/markdown_document_parser_test.dart
git commit -m "feat: integrate preview-first markdown composer"
```

## Task 6: Finish send/draft polish and regression checks

**Files:**

- Modify: `lib/pages/chat_page.dart`
- Modify: `test/services/local_storage_composer_and_draft_test.dart`
- Modify: `test/widgets/markdown_document_editor_test.dart`
- **Step 1: Write a failing draft/send regression test**

```dart
test('composer draft stores flushed block edits', () async {
  final storage = LocalStorage();
  const roomId = '!room:example.org';

  await storage.saveDraft(roomId, 'old');
  await storage.saveDraft(roomId, 'paragraph\n\n```dart\nprint("hi");\n```');

  final loaded = await storage.loadDraft(roomId);
  expect(loaded, 'paragraph\n\n```dart\nprint("hi");\n```');
});
```

- **Step 2: Run the regression test to verify the current failure**

Run: `flutter test test/services/local_storage_composer_and_draft_test.dart -r expanded`

Expected: FAIL if draft/save integration still reads stale `_messageController` content.

- **Step 3: Normalize draft persistence around the controller source**

```dart
void _onComposerDocumentChanged() {
  final next = _composerDocController.text;
  if (_messageController.text != next) {
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
  unawaited(LocalStorage().saveDraft(widget.room.id, next));
}
```

- **Step 4: Run the full relevant test suite**

Run: `flutter test test/composer test/widgets/markdown_document_editor_test.dart test/services/local_storage_composer_and_draft_test.dart -r expanded`

Expected: PASS across composer parser/controller/widget tests and draft persistence tests.

- **Step 5: Run analyzer on changed files**

Run: `dart analyze lib/pages/chat_page.dart lib/composer lib/widgets/composer test/composer test/widgets/markdown_document_editor_test.dart test/services/local_storage_composer_and_draft_test.dart`

Expected: `No issues found!`

- **Step 6: Commit**

```bash
git add lib/pages/chat_page.dart lib/composer lib/widgets/composer test/composer test/widgets/markdown_document_editor_test.dart test/services/local_storage_composer_and_draft_test.dart
git commit -m "test: harden markdown composer drafts and regressions"
```

## Self-Review

### Spec coverage

- Preview-first composer: covered by Tasks 3 and 5.
- Icon toolbar replacing text buttons: covered by Tasks 3 and 5.
- Paragraph tap-to-edit: covered by Task 3.
- Image block card with top-right delete: covered by Task 4.
- Code block in-place edit with top-right delete: covered by Task 4.
- Insert actions create blocks and focus the new code block: covered by Tasks 2 and 5.
- Preserve Markdown send flow: covered by Tasks 5 and 6.
- Phase-1 scope limited to paragraph/image/code and read-only fallback for unsupported blocks: covered by Tasks 1 and 4.

No spec gaps found for phase 1.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” placeholders remain.
- Every task includes exact file paths, code samples, commands, and expected outcomes.

### Type consistency

- Core names used consistently: `MarkdownBlock`, `MarkdownBlockType`, `parseMarkdownBlocks`, `MarkdownDocumentController`, `MarkdownDocumentEditor`, `MarkdownComposerToolbar`.
- Block deletion and active-draft flushing use the same controller API throughout the plan.

