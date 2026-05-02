# Mobile Markdown Source Composer Design

## Summary

This spec replaces the current block-based mobile composer with a source-first Markdown editor optimized for phone typing speed.

The user experience goal is:

- expanded composer opens in raw Markdown source mode by default
- the source surface is one full-document editor, not per-block editing
- a lightweight top-right icon toggles between source editing and full preview
- send remains a floating action in the bottom-right corner
- images, videos, links, and code blocks stay visible as Markdown source in edit mode
- source mode adds syntax highlighting so media/link syntax is easier to scan without rendering inline cards

## Goals

- Make mobile authoring fastest in the default state by letting the user type plain Markdown immediately.
- Keep the current Matrix send path and local draft persistence unchanged at the protocol level.
- Preserve a full preview mode for checking final rendering only when the user explicitly asks for it.
- Remove the block-model editing layer from the composer so there is one source of truth.

## Non-Goals

- Adding rich-text editing, inline media cards, or object-style block manipulation in the composer.
- Changing message storage, transport, or final message rendering semantics.
- Building a complete IDE-grade Markdown lexer; lightweight token highlighting is enough.

## Current State

The current mobile composer in `lib/pages/chat_page.dart` still sends a single Markdown string, but the expanded editor uses `MarkdownDocumentController` and `MarkdownDocumentEditor` to parse that string into blocks and edit those blocks individually.

That design adds complexity the user no longer wants on mobile:

- text input is split between `_messageController` and `_composerDocController`
- send and draft flows must flush document state before reading the real text
- images and videos appear as block previews instead of remaining editable source
- the expanded surface optimizes preview-first interaction instead of rapid raw typing

## Proposed Design

### Authoritative Text Model

`_messageController` becomes the only authoritative composer state.

Rules:

- collapsed composer and expanded composer both read/write the same controller
- draft persistence reads and writes `_messageController.text`
- send reads `_messageController.text.trim()`
- toolbar insertion mutates `_messageController` directly at the current selection when possible

`MarkdownDocumentController` and its parser/block types are removed from the composer flow and then deleted once the new UI is in place.

### Expanded Composer Layout

The expanded composer keeps the existing resize handle, toolbar row, rounded editor container, and floating send button, but the document body changes:

- **Source mode (default):** a single multiline Markdown editor fills the container
- **Preview mode:** the same container renders `MarkdownRenderer(data: _messageController.text, ...)`
- **Top-right toggle:** an icon-only control sits in the toolbar trailing area and switches between source and preview
- **Bottom-right send:** the send button remains floating inside the editor container

Each time the composer is expanded, it opens in source mode to match the user's "typing first, preview on demand" workflow.

### Source Editor

Create a dedicated source widget, for example:

- `MarkdownSourceEditor`
  - hosts a multiline text field sized for the full expanded area
  - exposes the current `TextEditingController`
  - uses a syntax-highlighting controller or `buildTextSpan` strategy
  - adds enough bottom padding so the floating send button does not cover the last lines

Create a dedicated controller helper, for example:

- `MarkdownSyntaxTextEditingController`
  - extends `TextEditingController`
  - overrides `buildTextSpan`
  - highlights common Markdown tokens:
    - headings
    - fenced code delimiters
    - inline code
    - links
    - images
    - block quotes
    - emphasis markers
    - list markers

The source view does **not** render media objects. A line such as `![cat](r2://...)` or `[clip.mp4（视频）](r2://...)` stays text-only and is only syntax-highlighted.

### Toolbar Behavior

The toolbar remains icon-based and always visible in expanded mode.

Actions:

- insert code fence
- insert image Markdown after upload
- insert video Markdown after upload
- insert audio Markdown after upload
- insert file Markdown after upload
- toggle source/preview mode
- collapse composer

Insertion behavior is text-first:

- if there is a selection, replace it with the snippet
- otherwise insert at the current cursor
- when snippet boundaries need spacing, normalize surrounding newlines so the inserted Markdown is valid and readable

### Preview Mode

Preview mode uses `MarkdownRenderer` against `_messageController.text` directly. This keeps composer preview aligned with message bubble rendering and avoids a second preview implementation.

Preview mode is read-only. Returning to source mode restores the same text and caret state.

### Cleanup

Once the source-first composer is integrated and covered by tests, remove the obsolete block-based composer files and tests:

- `lib/composer/markdown_block.dart`
- `lib/composer/markdown_document_controller.dart`
- `lib/composer/markdown_document_parser.dart`
- `lib/widgets/composer/block_context_menu.dart`
- `lib/widgets/composer/code_block.dart`
- `lib/widgets/composer/image_block.dart`
- `lib/widgets/composer/markdown_document_editor.dart`
- `lib/widgets/composer/paragraph_block.dart`
- `lib/widgets/composer/video_block.dart`
- block-editor-specific tests under `test/composer/` and `test/widgets/`

This avoids leaving two competing composer models in the tree.

## Risks and Mitigations

### Syntax highlighting in editable text

Risk:

- editable syntax highlighting can become fragile if it tries to fully parse Markdown

Mitigation:

- keep highlighting lightweight and token-based
- test only visible token classes and plain-text preservation
- avoid structural rewriting in the highlighter

### Snippet insertion around cursor and selections

Risk:

- media/code insertions can produce malformed spacing or jump the caret unexpectedly

Mitigation:

- centralize insertion in one helper
- cover prepend, append, middle-of-document, and selection replacement cases with tests

### Preview/source toggle drift

Risk:

- preview could show stale text if it reads a derived source instead of the live controller

Mitigation:

- preview always renders `_messageController.text`
- widget tests should toggle modes after editing and verify the rendered text updates

## Testing Strategy

- unit tests for Markdown syntax highlighting spans
- widget tests for the source editor and the source/preview toggle
- widget tests for toolbar insertion into raw source text
- regression tests proving expanded and collapsed composer share one controller value
- `flutter analyze` and `flutter test` before completion

## Success Criteria

- expanding the composer always opens a full-document Markdown source editor
- images and videos remain visible as Markdown source while editing
- the preview icon switches between source and full preview without losing text
- send still transmits the exact Markdown source string
- no block-based composer controller remains in the active code path
