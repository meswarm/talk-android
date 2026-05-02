# Mobile Markdown Source Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mobile block-based Markdown composer with a full-document source editor that defaults to raw Markdown editing, toggles into preview on demand, and keeps send/draft behavior wired to a single text controller.

**Architecture:** Introduce a lightweight source-editor stack made of a syntax-highlighting text controller, a `MarkdownSourceEditor` widget, and an extracted mobile composer widget that owns the source/preview toggle UI. Then simplify `ChatPage` so `_messageController` becomes the only composer state, migrate toolbar insertion to direct text insertion at the caret, and delete the obsolete block-editor pipeline.

**Tech Stack:** Flutter, Dart, `flutter_test`, existing `MarkdownRenderer`, existing `R2Service` helpers, existing `LocalStorage`

---

## File Structure

### Create

- `lib/composer/markdown_insertion.dart`
  - Pure helper that inserts Markdown snippets into a string at the current `TextSelection` and returns the next `TextEditingValue`.
- `lib/widgets/composer/markdown_syntax_text_editing_controller.dart`
  - Source-editor controller that overrides `buildTextSpan` for lightweight Markdown token highlighting.
- `lib/widgets/composer/markdown_source_editor.dart`
  - Full-document multiline Markdown editor with editor padding sized for the floating send button.
- `lib/widgets/composer/mobile_markdown_composer.dart`
  - Extracted expanded-composer widget that renders the toolbar, source/preview body, preview toggle, and floating send button.
- `test/composer/markdown_insertion_test.dart`
  - Unit tests for caret insertion and newline normalization.
- `test/widgets/composer/markdown_syntax_text_editing_controller_test.dart`
  - Unit-style widget tests for highlighted spans.
- `test/widgets/composer/markdown_source_editor_test.dart`
  - Widget tests for the source editor shell.
- `test/widgets/composer/mobile_markdown_composer_test.dart`
  - Widget tests for source/preview toggling and live preview rendering.

### Modify

- `lib/pages/chat_page.dart`
  - Remove block-based composer state, adopt the extracted mobile composer widget, and route all send/draft/media insertion behavior through `_messageController`.
- `lib/widgets/composer/markdown_composer_toolbar.dart`
  - Add an icon-only preview toggle action beside the existing collapse action.
- `test/services/local_storage_composer_and_draft_test.dart`
  - Keep draft coverage aligned if draft-save triggers or semantics need updates.

### Delete

- `lib/composer/markdown_block.dart`
- `lib/composer/markdown_document_controller.dart`
- `lib/composer/markdown_document_parser.dart`
- `lib/widgets/composer/block_context_menu.dart`
- `lib/widgets/composer/code_block.dart`
- `lib/widgets/composer/image_block.dart`
- `lib/widgets/composer/markdown_document_editor.dart`
- `lib/widgets/composer/paragraph_block.dart`
- `lib/widgets/composer/video_block.dart`
- `test/composer/markdown_document_controller_test.dart`
- `test/composer/markdown_document_parser_test.dart`
- `test/widgets/markdown_document_editor_test.dart`

## Task 1: Add text-first insertion helpers and Markdown syntax highlighting primitives

**Files:**
- Create: `lib/composer/markdown_insertion.dart`
- Create: `lib/widgets/composer/markdown_syntax_text_editing_controller.dart`
- Create: `test/composer/markdown_insertion_test.dart`
- Create: `test/widgets/composer/markdown_syntax_text_editing_controller_test.dart`

- [ ] **Step 1: Write the failing insertion and highlighting tests**

```dart
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

  expect(next.text, 'hello ![cat](r2://bucket/cat.png?mime=image%2Fpng)');
});

test('highlights image and video markdown as media tokens', () {
  final controller = MarkdownSyntaxTextEditingController()
    ..text = '![cat](r2://bucket/cat.png?mime=image%2Fpng)\n'
        '[clip.mp4（视频）](r2://bucket/clip.mp4?mime=video%2Fmp4)';

  final span = controller.buildTextSpan(
    context: null,
    style: const TextStyle(color: Colors.black),
    withComposing: false,
  );

  expect(span.toPlainText(), controller.text);
  expect(flattenTextSpans(span).where((s) => s.text!.contains('![')).length, 1);
  expect(flattenTextSpans(span).where((s) => s.text!.contains('[clip.mp4')).length, 1);
});
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
flutter test test/composer/markdown_insertion_test.dart \
  test/widgets/composer/markdown_syntax_text_editing_controller_test.dart -r expanded
```

Expected: FAIL because neither helper file exists yet.

- [ ] **Step 3: Implement `insertMarkdownSnippet()` as a pure helper**

```dart
TextEditingValue insertMarkdownSnippet({
  required String text,
  required TextSelection selection,
  required String snippet,
}) {
  final safeSelection = selection.isValid
      ? selection
      : TextSelection.collapsed(offset: text.length);
  final start = safeSelection.start;
  final end = safeSelection.end;
  final before = text.substring(0, start).replaceAll(RegExp(r'\s+$'), '');
  final after = text.substring(end).replaceAll(RegExp(r'^\s+'), '');
  final needsLeadingBreak = before.isNotEmpty;
  final needsTrailingBreak = after.isNotEmpty;
  final inserted = [
    if (needsLeadingBreak) before else before,
    if (needsLeadingBreak) '\n\n',
    snippet.trim(),
    if (needsTrailingBreak) '\n\n',
    after,
  ].join();
  return TextEditingValue(
    text: inserted,
    selection: TextSelection.collapsed(offset: (before + (needsLeadingBreak ? '\n\n' : '') + snippet.trim()).length),
  );
}
```

- [ ] **Step 4: Implement the syntax-highlighting controller**

```dart
class MarkdownSyntaxTextEditingController extends TextEditingController {
  MarkdownSyntaxTextEditingController({super.text});

  static final _patterns = <({RegExp regex, TextStyle Function(TextStyle) style})>[
    (regex: RegExp(r'^\s{0,3}#{1,6}\s.*$', multiLine: true), style: _headingStyle),
    (regex: RegExp(r'!\[[^\]]*\]\([^)]+\)'), style: _mediaStyle),
    (regex: RegExp(r'\[[^\]]+\]\([^)]+\)'), style: _linkStyle),
    (regex: RegExp(r'`[^`\n]+`'), style: _inlineCodeStyle),
    (regex: RegExp(r'^\s{0,3}(```|~~~).*$', multiLine: true), style: _fenceStyle),
    (regex: RegExp(r'^\s{0,3}(>|\- |\* |\d+\. ).*$', multiLine: true), style: _markerStyle),
  ];

  @override
  TextSpan buildTextSpan({
    required BuildContext? context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return buildMarkdownHighlightSpan(text, base);
  }
}
```

Use a helper that walks all regex matches in source order and emits non-overlapping `TextSpan`s so `toPlainText()` still matches the original text exactly.

- [ ] **Step 5: Re-run the focused tests**

Run:

```bash
flutter test test/composer/markdown_insertion_test.dart \
  test/widgets/composer/markdown_syntax_text_editing_controller_test.dart -r expanded
```

Expected: PASS for caret insertion, selection replacement, and media-token highlighting.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/composer/markdown_insertion.dart \
  lib/widgets/composer/markdown_syntax_text_editing_controller.dart \
  test/composer/markdown_insertion_test.dart \
  test/widgets/composer/markdown_syntax_text_editing_controller_test.dart
git commit -m "feat: add markdown source editing primitives"
```

## Task 2: Build the source editor widget and extracted mobile composer shell

**Files:**
- Create: `lib/widgets/composer/markdown_source_editor.dart`
- Create: `lib/widgets/composer/mobile_markdown_composer.dart`
- Modify: `lib/widgets/composer/markdown_composer_toolbar.dart`
- Create: `test/widgets/composer/markdown_source_editor_test.dart`
- Create: `test/widgets/composer/mobile_markdown_composer_test.dart`

- [ ] **Step 1: Write the failing widget tests for source mode and preview mode**

```dart
testWidgets('source editor shows multiline text field with bottom safe padding', (tester) async {
  final controller = MarkdownSyntaxTextEditingController(text: '# hi');

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MarkdownSourceEditor(
          controller: controller,
          focusNode: FocusNode(),
          isDark: false,
          bottomInset: 56,
          onChanged: (_) {},
        ),
      ),
    ),
  );

  expect(find.byType(TextField), findsOneWidget);
  expect(find.text('# hi'), findsOneWidget);
});

testWidgets('mobile composer toggles from source to preview and back', (tester) async {
  final controller = MarkdownSyntaxTextEditingController(text: '# Title');

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MobileMarkdownComposer(
          controller: controller,
          focusNode: FocusNode(),
          isDark: false,
          panelHeight: 500,
          composerHeightPct: 50,
          sending: false,
          uploadingMedia: false,
          onChanged: (_) {},
          onSend: () {},
          onInsertCode: () {},
          onInsertImage: () {},
          onInsertVideo: () {},
          onInsertAudio: () {},
          onInsertFile: () {},
          onCollapse: () {},
          onHeightPctChanged: (_) {},
        ),
      ),
    ),
  );

  expect(find.byType(MarkdownSourceEditor), findsOneWidget);
  expect(find.byType(MarkdownRenderer), findsNothing);

  await tester.tap(find.byTooltip('Preview'));
  await tester.pump();

  expect(find.byType(MarkdownRenderer), findsOneWidget);

  await tester.tap(find.byTooltip('Edit source'));
  await tester.pump();

  expect(find.byType(MarkdownSourceEditor), findsOneWidget);
});
```

- [ ] **Step 2: Run the widget tests and verify they fail**

Run:

```bash
flutter test test/widgets/composer/markdown_source_editor_test.dart \
  test/widgets/composer/mobile_markdown_composer_test.dart -r expanded
```

Expected: FAIL because the new widgets and toolbar toggle API do not exist yet.

- [ ] **Step 3: Implement `MarkdownSourceEditor`**

```dart
class MarkdownSourceEditor extends StatelessWidget {
  const MarkdownSourceEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.bottomInset,
    required this.onChanged,
    this.readOnly = false,
  });

  final MarkdownSyntaxTextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final double bottomInset;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      expands: true,
      minLines: null,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      onChanged: onChanged,
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
      ),
    );
  }
}
```

- [ ] **Step 4: Extend the toolbar API with a preview toggle**

```dart
class MarkdownComposerToolbar extends StatelessWidget {
  const MarkdownComposerToolbar({
    super.key,
    required this.enabled,
    required this.previewing,
    required this.onTogglePreview,
    required this.onInsertCode,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertAudio,
    required this.onInsertFile,
    required this.onCollapse,
  });

  final bool previewing;
  final VoidCallback onTogglePreview;
```

Render the trailing actions as:

```dart
IconButton(
  tooltip: previewing ? 'Edit source' : 'Preview',
  onPressed: enabled ? onTogglePreview : null,
  icon: Icon(previewing ? Icons.edit_note : Icons.visibility_outlined),
),
IconButton(
  tooltip: 'Collapse',
  onPressed: enabled ? onCollapse : null,
  icon: const Icon(Icons.expand_more),
),
```

- [ ] **Step 5: Implement `MobileMarkdownComposer`**

```dart
enum ComposerViewMode { source, preview }

class MobileMarkdownComposer extends StatelessWidget {
  const MobileMarkdownComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.panelHeight,
    required this.composerHeightPct,
    required this.sending,
    required this.uploadingMedia,
    required this.onChanged,
    required this.onSend,
    required this.onInsertCode,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertAudio,
    required this.onInsertFile,
    required this.onCollapse,
    required this.onHeightPctChanged,
  });
```

Inside the body:

```dart
child: Stack(
  fit: StackFit.expand,
  children: [
    viewMode == ComposerViewMode.preview
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 68),
            child: MarkdownRenderer(data: controller.text, isDark: isDark),
          )
        : MarkdownSourceEditor(
            controller: controller,
            focusNode: focusNode,
            isDark: isDark,
            bottomInset: 56,
            readOnly: uploadingMedia,
            onChanged: onChanged,
          ),
    Positioned(right: 8, bottom: 8, child: sendButton),
  ],
),
```

- [ ] **Step 6: Re-run the widget tests**

Run:

```bash
flutter test test/widgets/composer/markdown_source_editor_test.dart \
  test/widgets/composer/mobile_markdown_composer_test.dart -r expanded
```

Expected: PASS, including the source/preview toggle and live preview rendering.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/widgets/composer/markdown_source_editor.dart \
  lib/widgets/composer/mobile_markdown_composer.dart \
  lib/widgets/composer/markdown_composer_toolbar.dart \
  test/widgets/composer/markdown_source_editor_test.dart \
  test/widgets/composer/mobile_markdown_composer_test.dart
git commit -m "feat: add mobile markdown source composer shell"
```

## Task 3: Rewire `ChatPage` to use a single source controller

**Files:**
- Modify: `lib/pages/chat_page.dart`
- Modify: `test/services/local_storage_composer_and_draft_test.dart`

- [ ] **Step 1: Write the failing tests for single-source composer behavior**

Prefer a focused widget test around the extracted composer host, not the full Matrix room page. Add assertions for:

```dart
testWidgets('preview reflects the live markdown source', (tester) async {
  final controller = MarkdownSyntaxTextEditingController(text: '# before');

  await pumpComposerHost(tester, controller: controller);

  controller.text = '# after';
  await tester.pump();

  await tester.tap(find.byTooltip('Preview'));
  await tester.pump();

  expect(find.text('after'), findsOneWidget);
});

test('insert helper keeps cursor after appended video markdown', () {
  final next = insertMarkdownSnippet(
    text: 'hello',
    selection: const TextSelection.collapsed(offset: 5),
    snippet: '[clip.mp4（视频）](r2://bucket/clip.mp4?mime=video%2Fmp4)',
  );

  expect(next.text, contains('[clip.mp4（视频）]'));
});
```

If the current draft tests assume `_composerDocController`, replace them with assertions that draft save/load still round-trip through plain source text.

- [ ] **Step 2: Run the relevant tests and verify they fail**

Run:

```bash
flutter test test/composer/markdown_insertion_test.dart \
  test/widgets/composer/mobile_markdown_composer_test.dart \
  test/services/local_storage_composer_and_draft_test.dart -r expanded
```

Expected: FAIL because `ChatPage` still flushes and reads `_composerDocController`.

- [ ] **Step 3: Remove block-controller state from `ChatPage`**

Delete these members and methods:

```dart
late final MarkdownDocumentController _composerDocController;
bool _syncingComposerFromDoc = false;

void _onComposerDocumentChanged() { ... }
```

Replace them with:

```dart
late final MarkdownSyntaxTextEditingController _messageController;
ComposerViewMode _composerViewMode = ComposerViewMode.source;
```

Initialize in `initState()`:

```dart
_messageController = MarkdownSyntaxTextEditingController();
_messageController.addListener(() {
  _onComposerTextChanged(_messageController.text);
});
```

- [ ] **Step 4: Make expand/send/draft flows source-only**

Update these methods:

```dart
void _expandComposer() {
  if (_composerExpanded) return;
  setState(() {
    _composerExpanded = true;
    _composerViewMode = ComposerViewMode.source;
  });
}

Future<void> _sendMessage() async {
  final text = _messageController.text.trim();
  if (text.isEmpty || _sending || _uploadingMedia) return;

  setState(() => _sending = true);
  _messageController.clear();
  _stopLocalTyping();
  // existing sendTextEvent / clearDraft flow stays the same
}

Future<void> _loadDraft() async {
  final draft = await LocalStorage().getDraft(widget.room.id);
  if (draft.isNotEmpty && mounted) {
    _messageController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }
}
```

During `dispose()`, save `final text = _messageController.text.trim();` directly.

- [ ] **Step 5: Replace append-only insertion with caret-aware insertion**

Replace `_appendComposerMarkdown()` with:

```dart
void _insertComposerSnippet(String snippet) {
  final next = insertMarkdownSnippet(
    text: _messageController.text,
    selection: _messageController.selection,
    snippet: snippet,
  );
  _messageController.value = next;
  unawaited(LocalStorage().saveDraft(widget.room.id, next.text));
}
```

Use `_insertComposerSnippet()` from:

- `_insertCodeBlockFromToolbar()`
- `_uploadR2AndInsertMarkdown()` for image/video/audio/file snippets

Video uploads no longer call `insertVideoBlock()`; they insert the raw Markdown snippet the same way every other media type does.

- [ ] **Step 6: Replace the expanded composer body with `MobileMarkdownComposer`**

In `_buildExpandedComposer()`:

```dart
return MobileMarkdownComposer(
  controller: _messageController,
  focusNode: _composerTextFocus,
  isDark: isDark,
  panelHeight: panelH,
  composerHeightPct: _composerHeightPct,
  sending: _sending,
  uploadingMedia: _uploadingMedia,
  onChanged: _onComposerTextChanged,
  onSend: _sendMessage,
  onInsertCode: _insertCodeBlockFromToolbar,
  onInsertImage: _pickAndSendImage,
  onInsertVideo: _pickAndSendVideo,
  onInsertAudio: _pickAndSendAudio,
  onInsertFile: _pickAndSendFile,
  onCollapse: _collapseComposer,
  onTogglePreview: () {
    setState(() {
      _composerViewMode = _composerViewMode == ComposerViewMode.source
          ? ComposerViewMode.preview
          : ComposerViewMode.source;
    });
  },
  viewMode: _composerViewMode,
  onHeightPctChanged: (next) => setState(() => _composerHeightPct = next),
);
```

- [ ] **Step 7: Re-run the focused tests**

Run:

```bash
flutter test test/composer/markdown_insertion_test.dart \
  test/widgets/composer/mobile_markdown_composer_test.dart \
  test/services/local_storage_composer_and_draft_test.dart -r expanded
```

Expected: PASS, with draft persistence still green and preview always reflecting source text.

- [ ] **Step 8: Commit**

Run:

```bash
git add lib/pages/chat_page.dart \
  test/services/local_storage_composer_and_draft_test.dart
git commit -m "refactor: make chat composer source-first"
```

## Task 4: Delete the obsolete block-based composer implementation

**Files:**
- Delete: `lib/composer/markdown_block.dart`
- Delete: `lib/composer/markdown_document_controller.dart`
- Delete: `lib/composer/markdown_document_parser.dart`
- Delete: `lib/widgets/composer/block_context_menu.dart`
- Delete: `lib/widgets/composer/code_block.dart`
- Delete: `lib/widgets/composer/image_block.dart`
- Delete: `lib/widgets/composer/markdown_document_editor.dart`
- Delete: `lib/widgets/composer/paragraph_block.dart`
- Delete: `lib/widgets/composer/video_block.dart`
- Delete: `test/composer/markdown_document_controller_test.dart`
- Delete: `test/composer/markdown_document_parser_test.dart`
- Delete: `test/widgets/markdown_document_editor_test.dart`

- [ ] **Step 1: Verify the old block-based files are no longer referenced**

Run:

```bash
rg "MarkdownDocumentController|MarkdownDocumentEditor|MarkdownBlockType" lib test
```

Expected: only docs or already-planned deletions remain.

- [ ] **Step 2: Delete the obsolete files**

Remove the files listed above, then clean up any now-unused imports from `chat_page.dart`, tests, and docs references that break analysis.

- [ ] **Step 3: Run the full test suite to catch stale references**

Run:

```bash
flutter test -r expanded
```

Expected: PASS without any import errors or missing-symbol failures tied to the deleted block-based composer.

- [ ] **Step 4: Commit**

Run:

```bash
git add -A
git commit -m "refactor: remove obsolete block composer code"
```

## Task 5: Final verification and polish

**Files:**
- Modify: any files required only if verification exposes real defects

- [ ] **Step 1: Run analyzer on the new composer surface**

Run:

```bash
flutter analyze \
  lib/pages/chat_page.dart \
  lib/composer/markdown_insertion.dart \
  lib/widgets/composer/markdown_syntax_text_editing_controller.dart \
  lib/widgets/composer/markdown_source_editor.dart \
  lib/widgets/composer/mobile_markdown_composer.dart \
  lib/widgets/composer/markdown_composer_toolbar.dart
```

Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Do a manual mobile smoke pass**

Check these flows on device/emulator:

- expand composer -> source mode opens immediately
- type plain Markdown in source mode
- insert image/video/code at the caret
- tap preview icon -> rendered preview matches typed source
- tap preview icon again -> returns to source mode without losing text
- send message -> sent bubble matches preview
- collapse and reopen -> composer reopens in source mode

- [ ] **Step 4: Commit**

Run:

```bash
git add -A
git commit -m "test: verify mobile markdown source composer"
```
