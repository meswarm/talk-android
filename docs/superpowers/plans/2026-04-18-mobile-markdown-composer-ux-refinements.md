# Mobile Markdown Composer UX Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the mobile Markdown composer so text entry feels immediate, block deletion avoids accidental taps, and video attachments render as first-class previewable blocks.

**Architecture:** Extend the existing block-based composer instead of replacing it. Add a `video` block type to the parser/controller pipeline, replace top-right delete buttons with long-press context menus, and let the document editor create and focus a paragraph block when the user taps empty space so plain text remains the default authoring mode.

**Tech Stack:** Flutter, Dart, Provider, existing `MarkdownRenderer`, existing R2 helpers, `video_player`, `flutter_test`

---

## File Structure

### Modify

- `lib/composer/markdown_block.dart`
  - Add `MarkdownBlockType.video`.
- `lib/composer/markdown_document_parser.dart`
  - Detect full-line video links and emit `video` blocks.
- `lib/composer/markdown_document_controller.dart`
  - Add transient paragraph-draft helpers and video insertion helpers.
- `lib/widgets/composer/markdown_document_editor.dart`
  - Render `video` blocks, add empty-space tap handling, and host long-press menus.
- `lib/widgets/composer/paragraph_block.dart`
  - Keep single-tap-to-edit behavior and expose a focused empty paragraph state cleanly.
- `lib/widgets/composer/image_block.dart`
  - Remove always-visible delete `X`; trigger delete from long press.
- `lib/widgets/composer/code_block.dart`
  - Remove always-visible delete `X`; trigger delete from long press.
- `lib/pages/chat_page.dart`
  - Insert videos as video blocks rather than plain paragraph links.
- `test/composer/markdown_document_parser_test.dart`
  - Cover `video` parsing rules.
- `test/composer/markdown_document_controller_test.dart`
  - Cover paragraph creation/activation and video insertion.
- `test/widgets/markdown_document_editor_test.dart`
  - Cover long-press delete menus, immediate text entry, and video preview expansion.

### Create

- `lib/widgets/composer/block_context_menu.dart`
  - Shared long-press menu helper for destructive block actions.
- `lib/widgets/composer/video_block.dart`
  - Collapsed preview card + inline expandable player for video blocks.

### Dependency

- `pubspec.yaml`
  - Add `video_player` with `flutter pub add video_player`.

## Task 1: Extend the block model and parser for video lines

**Files:**
- Modify: `lib/composer/markdown_block.dart`
- Modify: `lib/composer/markdown_document_parser.dart`
- Test: `test/composer/markdown_document_parser_test.dart`

- [ ] **Step 1: Add parser tests for full-line video links**

```dart
test('parses a full-line video link as a video block', () {
  const source = '''
Hello

[clip.mp4](r2://bucket/clip.mp4?mime=video%2Fmp4)
''';

  final blocks = parseMarkdownBlocks(source);

  expect(blocks.map((b) => b.type).toList(), [
    MarkdownBlockType.paragraph,
    MarkdownBlockType.video,
  ]);
  expect(blocks[1].sourceText,
      '[clip.mp4](r2://bucket/clip.mp4?mime=video%2Fmp4)');
  expect(blocks[1].url, 'r2://bucket/clip.mp4?mime=video%2Fmp4');
});

test('keeps non-video full-line links as paragraph text', () {
  const source = '[docs](https://example.com/docs)';

  final blocks = parseMarkdownBlocks(source);

  expect(blocks, hasLength(1));
  expect(blocks.single.type, MarkdownBlockType.paragraph);
});
```

- [ ] **Step 2: Run the parser test and verify it fails**

Run: `flutter test test/composer/markdown_document_parser_test.dart -r expanded`

Expected: FAIL because `MarkdownBlockType.video` does not exist and the parser still classifies the link as a paragraph.

- [ ] **Step 3: Add the new block type**

```dart
enum MarkdownBlockType {
  paragraph,
  image,
  video,
  codeBlock,
  unsupportedBlock,
}
```

- [ ] **Step 4: Teach the parser to recognize full-line video links**

```dart
final linkLine = RegExp(r'^\[(.*?)\]\((.+?)\)$');

bool _looksLikeVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('mime=video%2f') ||
      lower.endsWith('.mp4') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v');
}

(String label, String url)? parseFullLineVideo(String line) {
  final trimmed = line.trim();
  final m = linkLine.firstMatch(trimmed);
  if (m == null || m.group(0) != trimmed) {
    return null;
  }
  final url = m.group(2)!;
  if (!_looksLikeVideoUrl(url)) {
    return null;
  }
  return (m.group(1)!, url);
}
```

Add a parser branch before paragraph capture:

```dart
if (isFullLineVideo(line)) {
  final parsed = parseFullLineVideo(line)!;
  final spanStart = trimmedSpanStart(i);
  final spanEnd = trimmedSpanEnd(i);
  final sourceText = source.substring(spanStart, spanEnd);
  blocks.add(
    MarkdownBlock(
      id: 'vid-$spanStart',
      type: MarkdownBlockType.video,
      startOffset: spanStart,
      endOffset: spanEnd,
      sourceText: sourceText,
      altText: parsed.$1,
      url: parsed.$2,
    ),
  );
  i++;
  continue;
}
```

- [ ] **Step 5: Re-run the parser test**

Run: `flutter test test/composer/markdown_document_parser_test.dart -r expanded`

Expected: PASS for the new video cases and the existing image/code/table cases.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/composer/markdown_block.dart \
  lib/composer/markdown_document_parser.dart \
  test/composer/markdown_document_parser_test.dart
git commit -m "feat: parse video blocks in markdown composer"
```

## Task 2: Add controller helpers for immediate text entry and video insertion

**Files:**
- Modify: `lib/composer/markdown_document_controller.dart`
- Test: `test/composer/markdown_document_controller_test.dart`

- [ ] **Step 1: Add controller tests for paragraph drafts and video insertion**

```dart
test('startParagraphDraftAtEnd opens an empty draft without mutating source', () {
  final controller = MarkdownDocumentController(initialText: '![cat](r2://cat)');

  controller.startParagraphDraftAtEnd();

  expect(controller.activeBlock, isNull);
  expect(controller.activeDraft, '');
  expect(controller.text, '![cat](r2://cat)');
  expect(controller.creatingParagraphDraft, isTrue);
});

test('flushActiveDraft commits a new paragraph draft at document end', () {
  final controller = MarkdownDocumentController(initialText: '![cat](r2://cat)');

  controller.startParagraphDraftAtEnd();
  controller.setActiveDraft('GG');
  controller.flushActiveDraft();

  expect(controller.creatingParagraphDraft, isFalse);
  expect(controller.blocks.last.type, MarkdownBlockType.paragraph);
  expect(controller.blocks.last.sourceText, 'GG');
  expect(controller.text, '![cat](r2://cat)\n\nGG');
});

test('insertVideoBlock appends a video block and activates nothing', () {
  final controller = MarkdownDocumentController(initialText: 'hello');

  controller.insertVideoBlock('[clip.mp4](r2://bucket/clip.mp4?mime=video%2Fmp4)');

  expect(controller.blocks.last.type, MarkdownBlockType.video);
  expect(controller.text,
      'hello\n\n[clip.mp4](r2://bucket/clip.mp4?mime=video%2Fmp4)');
  expect(controller.activeBlock, isNull);
});
```

- [ ] **Step 2: Run the controller tests and verify they fail**

Run: `flutter test test/composer/markdown_document_controller_test.dart -r expanded`

Expected: FAIL with undefined `startParagraphDraftAtEnd`, `creatingParagraphDraft`, and `insertVideoBlock`.

- [ ] **Step 3: Add transient paragraph-draft support**

```dart
int? _draftInsertOffset;
MarkdownBlockType? _draftBlockType;

bool get creatingParagraphDraft =>
    _draftBlockType == MarkdownBlockType.paragraph && _draftInsertOffset != null;

void startParagraphDraftAtEnd() {
  flushActiveDraft();
  _activeBlockId = null;
  _activeDraft = '';
  _draftInsertOffset = _text.length;
  _draftBlockType = MarkdownBlockType.paragraph;
  notifyListeners();
}
```

- [ ] **Step 4: Teach `flushActiveDraft()` how to commit or discard the transient paragraph**

```dart
void flushActiveDraft() {
  if (creatingParagraphDraft) {
    final insertAt = _draftInsertOffset!;
    final draft = (_activeDraft ?? '').trimRight();
    _draftInsertOffset = null;
    _draftBlockType = null;
    _activeDraft = null;
    if (draft.isEmpty) {
      notifyListeners();
      return;
    }
    final prefix = insertAt == 0 ? '' : '\n\n';
    _replaceRange(insertAt, insertAt, '$prefix$draft');
    return;
  }

  // existing block-flush behavior for paragraph/code continues here
}
```

- [ ] **Step 5: Add a dedicated video insertion helper**

```dart
void insertVideoBlock(String snippet) {
  flushActiveDraft();
  final insertAt = activeBlock?.endOffset ?? _text.length;
  final prefix = insertAt == 0 ? '' : '\n\n';
  _replaceRange(insertAt, insertAt, '$prefix$snippet');
  _activeBlockId = null;
  _activeDraft = null;
  notifyListeners();
}
```

- [ ] **Step 6: Re-run the controller tests**

Run: `flutter test test/composer/markdown_document_controller_test.dart -r expanded`

Expected: PASS for the new helper tests and the existing flush/delete/code tests.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/composer/markdown_document_controller.dart \
  test/composer/markdown_document_controller_test.dart
git commit -m "feat: add paragraph drafts and video helpers to composer controller"
```

## Task 3: Replace tap-delete buttons with long-press block menus

**Files:**
- Create: `lib/widgets/composer/block_context_menu.dart`
- Modify: `lib/widgets/composer/image_block.dart`
- Modify: `lib/widgets/composer/code_block.dart`
- Test: `test/widgets/markdown_document_editor_test.dart`

- [ ] **Step 1: Add a widget test for long-press delete**

```dart
testWidgets('long-pressing an image block shows a delete menu', (tester) async {
  final controller = MarkdownDocumentController(
    initialText: '![cat](r2://bucket/cat.png?mime=image%2Fpng)',
  );

  await tester.pumpWidget(_wrapEditor(controller));
  await tester.longPress(find.byType(ImageBlockCard));
  await tester.pumpAndSettle();

  expect(find.text('删除'), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget test and verify it fails**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL because the block widgets still show a permanent `IconButton` and no menu text appears.

- [ ] **Step 3: Add a shared long-press menu helper**

```dart
Future<void> showBlockContextMenu(
  BuildContext context, {
  required VoidCallback onDelete,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('删除'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    ),
  );
  if (action == 'delete') {
    onDelete();
  }
}
```

- [ ] **Step 4: Remove the always-visible `X` buttons from image and code blocks**

Wrap the block body with `GestureDetector`:

```dart
return GestureDetector(
  behavior: HitTestBehavior.opaque,
  onLongPress: () => showBlockContextMenu(
    context,
    onDelete: onDelete,
  ),
  child: Padding(
    padding: const EdgeInsets.only(top: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return MarkdownRenderer(
          data: block.sourceText,
          isDark: isDark,
          maxImageHeight: 140,
          maxImageWidth: constraints.maxWidth,
        );
      },
    ),
  ),
);
```

Apply the same pattern to `CodeBlock`, keeping tap-to-edit on short tap and reserving long press for menu open.

- [ ] **Step 5: Re-run the widget test**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: PASS for the new menu case and no regressions in the existing paragraph/code/image tests.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/widgets/composer/block_context_menu.dart \
  lib/widgets/composer/image_block.dart \
  lib/widgets/composer/code_block.dart \
  test/widgets/markdown_document_editor_test.dart
git commit -m "feat: use long-press menus for composer block deletion"
```

## Task 4: Make plain text entry immediate and default

**Files:**
- Modify: `lib/widgets/composer/markdown_document_editor.dart`
- Modify: `lib/widgets/composer/paragraph_block.dart`
- Test: `test/widgets/markdown_document_editor_test.dart`

- [ ] **Step 1: Add a widget test for tapping blank space to start typing**

```dart
testWidgets('tapping trailing empty space creates a paragraph editor', (tester) async {
  final controller = MarkdownDocumentController(
    initialText: '![cat](r2://bucket/cat.png?mime=image%2Fpng)',
  );

  await tester.pumpWidget(_wrapEditor(controller));
  await tester.tap(find.byKey(const ValueKey('composer-empty-space')));
  await tester.pump();

  expect(controller.creatingParagraphDraft, isTrue);
  expect(find.byType(TextField), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget test and verify it fails**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL because the editor has no empty-space tap target and no new paragraph is created.

- [ ] **Step 3: Add a trailing empty-space tap target to the document editor**

Append this after the block list:

```dart
Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 24),
  child: GestureDetector(
    key: const ValueKey('composer-empty-space'),
    behavior: HitTestBehavior.opaque,
    onTap: controller.startParagraphDraftAtEnd,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: const SizedBox.expand(),
    ),
  ),
),
```

This opens a transient paragraph draft instead of trying to parse an empty paragraph block into Markdown before the user types.

- [ ] **Step 4: Render a trailing draft editor when `creatingParagraphDraft` is true**

Append this after the empty-space tap target:

```dart
if (controller.creatingParagraphDraft)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: _ComposerDraftTextField(
      initialValue: controller.activeDraft ?? '',
      onChanged: controller.setActiveDraft,
      onEditingComplete: controller.flushActiveDraft,
    ),
  ),
```

Use a small stateful helper so the text controller is preserved across rebuilds:

```dart
class _ComposerDraftTextField extends StatefulWidget {
  const _ComposerDraftTextField({
    required this.initialValue,
    required this.onChanged,
    required this.onEditingComplete,
  });
}
```

Keep the trailing editor visually identical to ordinary paragraph editing so plain text remains the default mode.

- [ ] **Step 5: Keep paragraph editing as a single tap**

Ensure the paragraph preview path stays:

```dart
Positioned.fill(
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: widget.onTap,
    ),
  ),
)
```

Do not add any title-specific tool or mode; paragraph remains the default text block.

- [ ] **Step 6: Re-run the widget test**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: PASS for the empty-space tap case and the existing paragraph tap-to-edit cases.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/widgets/composer/markdown_document_editor.dart \
  lib/widgets/composer/paragraph_block.dart \
  test/widgets/markdown_document_editor_test.dart
git commit -m "feat: make plain text entry immediate in composer"
```

## Task 5: Add video block preview with inline expand-to-play behavior

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/widgets/composer/video_block.dart`
- Modify: `lib/widgets/composer/markdown_document_editor.dart`
- Modify: `lib/pages/chat_page.dart`
- Test: `test/widgets/markdown_document_editor_test.dart`

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add video_player`

Expected: `pubspec.yaml` and `pubspec.lock` updated with `video_player`.

- [ ] **Step 2: Add a widget test for collapsed-to-expanded video behavior**

```dart
testWidgets('tapping a video block expands inline preview', (tester) async {
  final controller = MarkdownDocumentController(
    initialText: '[clip.mp4](https://example.com/clip.mp4)',
  );

  await tester.pumpWidget(_wrapEditor(controller));

  expect(find.text('clip.mp4'), findsOneWidget);
  expect(find.text('收起预览'), findsNothing);

  await tester.tap(find.byKey(const ValueKey('video-block-toggle')));
  await tester.pump();

  expect(find.text('收起预览'), findsOneWidget);
});
```

- [ ] **Step 3: Run the widget test and verify it fails**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: FAIL because `MarkdownDocumentEditor` cannot render `MarkdownBlockType.video`.

- [ ] **Step 4: Add the video block widget**

Use a collapsed card with the same frame treatment as images:

```dart
class VideoBlockCard extends StatefulWidget {
  const VideoBlockCard({
    super.key,
    required this.block,
    required this.isDark,
    required this.onDelete,
  });

  final MarkdownBlock block;
  final bool isDark;
  final VoidCallback onDelete;
}
```

Collapsed state:

```dart
ListTile(
  key: const ValueKey('video-block-toggle'),
  leading: const Icon(Icons.play_circle_outline),
  title: Text(block.altText ?? '视频'),
  subtitle: Text(block.url ?? ''),
  onTap: _toggleExpanded,
  onLongPress: _showDeleteMenu,
)
```

Expanded state:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    AspectRatio(
      aspectRatio: _controller.value.isInitialized
          ? _controller.value.aspectRatio
          : 16 / 9,
      child: VideoPlayer(_controller),
    ),
    TextButton(
      onPressed: _toggleExpanded,
      child: const Text('收起预览'),
    ),
  ],
)
```

Controller initialization rules:
- `http(s)` URL -> `VideoPlayerController.networkUrl(Uri.parse(url))`
- `r2://...` URL -> resolve through `R2Service.presignedGetUri(url)` first, then pass the result to `networkUrl`
- keep a loading spinner while the controller initializes
- on failure, show `视频暂时无法预览` plus the file name; long press delete must still work

- [ ] **Step 5: Render video blocks and insert them from chat page uploads**

In `MarkdownDocumentEditor`:

```dart
MarkdownBlockType.video => VideoBlockCard(
  key: ValueKey(block.id),
  block: block,
  isDark: isDark,
  onDelete: () => controller.deleteBlock(block.id),
),
```

In `ChatPage`, add a dedicated helper:

```dart
void _appendComposerVideo(String name, String url) {
  final snippet = '[$name]($url)';
  _composerDocController.insertVideoBlock(snippet);
}
```

Use it in the R2 video upload path instead of treating the snippet as a paragraph append.

- [ ] **Step 6: Re-run the widget tests**

Run: `flutter test test/widgets/markdown_document_editor_test.dart -r expanded`

Expected: PASS for video expansion and no regressions in existing editor tests.

- [ ] **Step 7: Commit**

Run:

```bash
git add pubspec.yaml pubspec.lock \
  lib/widgets/composer/video_block.dart \
  lib/widgets/composer/markdown_document_editor.dart \
  lib/pages/chat_page.dart \
  test/widgets/markdown_document_editor_test.dart
git commit -m "feat: preview video blocks in markdown composer"
```

## Task 6: Run focused verification and full regression suite

**Files:**
- Modify: `test/composer/markdown_document_parser_test.dart`
- Modify: `test/composer/markdown_document_controller_test.dart`
- Modify: `test/widgets/markdown_document_editor_test.dart`

- [ ] **Step 1: Run focused tests**

Run:

```bash
flutter test test/composer/markdown_document_parser_test.dart -r expanded
flutter test test/composer/markdown_document_controller_test.dart -r expanded
flutter test test/widgets/markdown_document_editor_test.dart -r expanded
```

Expected: PASS for all focused composer tests.

- [ ] **Step 2: Run static analysis for touched files**

Run:

```bash
flutter analyze \
  lib/composer/markdown_block.dart \
  lib/composer/markdown_document_parser.dart \
  lib/composer/markdown_document_controller.dart \
  lib/widgets/composer/block_context_menu.dart \
  lib/widgets/composer/markdown_document_editor.dart \
  lib/widgets/composer/paragraph_block.dart \
  lib/widgets/composer/image_block.dart \
  lib/widgets/composer/code_block.dart \
  lib/widgets/composer/video_block.dart \
  lib/pages/chat_page.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run the full Flutter test suite**

Run: `flutter test`

Expected: `All tests passed!`

- [ ] **Step 4: Commit the verification-safe final state**

Run:

```bash
git add test/composer/markdown_document_parser_test.dart \
  test/composer/markdown_document_controller_test.dart \
  test/widgets/markdown_document_editor_test.dart
git commit -m "test: cover composer ux refinements"
```

## Self-Review

- **Spec coverage:** This plan covers the newly approved refinements: long-press deletion, immediate plain-text entry, and inline video preview. It intentionally does not revisit earlier MVP items that are already implemented.
- **Placeholder scan:** No `TODO`, `TBD`, or “handle later” markers remain. Every task lists concrete files, commands, and expected behavior.
- **Type consistency:** The plan consistently uses `MarkdownBlockType.video`, `appendParagraphAndActivate()`, `insertVideoBlock(String snippet)`, `showBlockContextMenu(...)`, and `VideoBlockCard`.
