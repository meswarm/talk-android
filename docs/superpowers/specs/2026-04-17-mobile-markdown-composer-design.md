## Mobile Markdown Composer Design

### Summary

This spec redesigns the mobile Markdown composer from a source-first `TextField` with a preview overlay into a block-based, preview-first editor that still stores and sends a single Markdown string.

The user experience goal is:

- a compact icon toolbar pinned above the composer
- preview as the default editing surface
- tap a paragraph to edit that paragraph in place
- tap a code block to edit that block in place
- show a small delete button on image and code blocks
- inserting media or code creates a block instead of forcing the user to type Markdown syntax manually
- keep Markdown as the only persisted and transmitted format

### Goals

- Make mobile Markdown authoring feel like direct manipulation instead of raw syntax editing.
- Preserve compatibility with existing Matrix send flow and existing Markdown rendering.
- Keep the first version focused on the highest-value block types: paragraph, image, and code block.
- Support block deletion through obvious UI controls instead of requiring manual syntax deletion.

### Non-Goals

- Building a full rich-text document model unrelated to Markdown.
- Supporting block-level editing for every Markdown construct in the first release.
- Changing how sent messages are stored on the server.
- Replacing `MarkdownRenderer` for message rendering.

## Current State

The current composer in `chat_page.dart` is:

- a large `TextField` for Markdown source
- a text-button toolbar with actions like code block and media insertion
- a `_composerPreview` mode that overlays a full preview on top of the source field
- a `源码` / `预览` toggle

This design works for power users but is awkward on mobile because:

- users must mentally map visible content to raw Markdown syntax
- image and code operations are syntax-driven rather than object-driven
- the toolbar consumes space with text labels
- preview and editing are split into separate modes

## Proposed Design

### Data Model

The composer keeps one authoritative Markdown string, plus a derived block list used for UI.

Recommended types:

- `MarkdownDocumentController`
  - owns the full Markdown source string
  - parses source into ordered blocks
  - tracks the active block id
  - exposes insert, update, delete, and flush operations
- `MarkdownBlock`
  - `id`
  - `type`
  - `startOffset`
  - `endOffset`
  - block-specific payload

Initial block types:

- `paragraph`
- `image`
- `codeBlock`
- `unsupportedBlock` for all other syntax rendered read-only in phase 1

Each block must retain its source range so UI actions can rewrite or remove the exact Markdown fragment.

### Rendering Structure

Replace the current source/preview dual-mode area with:

- `MarkdownComposerToolbar`
- `MarkdownDocumentEditor`
  - renders the ordered block list
  - delegates per-block behavior to block widgets
- block widgets:
  - `ParagraphBlockView`
  - `ParagraphBlockEditor`
  - `ImageBlockCard`
  - `CodeBlockView`
  - `CodeBlockEditor`

The current `_messageController` can remain as the underlying source holder for compatibility, but the block controller becomes the interaction owner.

### Editing Model

The editor is preview-first.

- Preview is the default state.
- Only one block is editable at a time.
- Entering another block first flushes pending edits from the current block back into Markdown source.
- All mutations follow the same pattern:

`user gesture -> block operation -> update source string -> reparse blocks -> rerender`

This keeps Markdown as the single persisted format while allowing direct-manipulation UI.

## Interaction Design

### Toolbar

The toolbar is always visible as one row of icon buttons above the editor.

Initial actions:

- insert code block
- insert image
- insert video
- insert audio
- insert file
- collapse composer

Text labels should be replaced with compact icons. Optional tooltip or semantics labels should remain for accessibility.

### Paragraph Blocks

Default state:

- rendered as normal preview content

On tap:

- that paragraph enters edit mode in place
- keyboard opens
- editing stays visually close to preview layout to avoid jarring jumps

On blur, block switch, or send:

- edited text flushes back into the Markdown source

This implements the requested "tap where the text is and edit there" behavior.

### Image Blocks

Inserted Markdown image syntax is rendered as an image card in the composer.

Behavior:

- image preview is shown inline
- a small delete button appears at the top-right corner
- tapping delete removes the entire corresponding Markdown image fragment
- tapping the image body may later support replace or view-original, but that is optional for phase 1

User mental model:

- they delete the image object

Actual data operation:

- remove the `![alt](url)` Markdown fragment for that block range

### Code Blocks

Default state:

- rendered as a normal code block preview

On tap:

- the full code block enters edit mode in place
- keyboard opens
- block stays visually code-like rather than becoming a generic full-width plain text field

Controls:

- small delete button at the top-right corner

Phase 1 editing scope:

- edit fenced code content
- language tag editing is optional and may be deferred if it complicates the first release

### Insert Behavior

Insert actions create blocks, not raw visible syntax workflows.

Rules:

- inserting a code block creates an empty fenced block and immediately enters that block's edit mode
- inserting an image uploads or inserts the image ref, then shows an image block card
- inserting media/file blocks in phase 1 may keep current behavior if not yet converted to block widgets
- insertion target is after the active block, or at document end if there is no active block

### Delete Behavior

Two deletion modes coexist:

- text editing deletion inside paragraph/code editors
- block deletion for image/code cards through explicit buttons

Users should not need to backspace through raw Markdown syntax for block removal.

## Focus and Input Rules

- Only one block can hold edit focus at a time.
- Tapping a paragraph or code block focuses that block and opens the keyboard.
- Tapping an image block does not open the keyboard.
- Tapping a delete button does not steal text focus before deletion.
- Tapping empty editor space should activate the last paragraph or create an empty paragraph at the end if needed.

These rules are intended to keep mobile keyboard behavior predictable.

## Send Flow

Sending remains Markdown-based.

Before send:

1. flush active block edits into source
2. read the controller's Markdown source
3. run existing validation
4. send through the current Matrix path

This avoids protocol or storage changes.

## Parsing Strategy

Phase 1 should use a constrained parser focused on supported block types rather than attempting full editable support for all Markdown constructs.

Recommended behavior:

- parse fenced code blocks explicitly
- parse Markdown image blocks explicitly
- treat plain text regions as paragraph blocks
- keep unsupported structures as read-only blocks rendered through existing `MarkdownRenderer`

This reduces risk while preserving fidelity for mixed content.

## Phased Scope

### Phase 1

- icon toolbar
- preview-first composer
- paragraph in-place editing
- image block render + delete
- code block render + in-place edit + delete
- source flush on send

### Deferred

- table block editing
- quote/list/divider editing
- video/audio/file block cards
- formula block editing
- drag reorder
- multi-block selection

Unsupported Markdown in phase 1 should still render, but as read-only blocks or fallback preview sections.

## Risks and Mitigations

### Source Range Drift

Risk:

- editing one block can invalidate offsets for following blocks

Mitigation:

- after every mutation, regenerate the full block list from the updated source rather than patching offsets incrementally

### Mixed Markdown Complexity

Risk:

- nested or less-common Markdown patterns may not map cleanly into editable blocks

Mitigation:

- support only paragraph/image/code as editable in phase 1
- fallback everything else to read-only block rendering

### Keyboard and Focus Instability

Risk:

- mobile keyboard may jump or dismiss unexpectedly when switching blocks

Mitigation:

- enforce single active editor
- flush before switching
- keep image cards non-focusable for text input

### Visual Jump Between Preview and Edit

Risk:

- tapping a paragraph or code block causes layout shift

Mitigation:

- style editors to match preview geometry closely
- avoid switching to a separate source panel

## Testing Strategy

### Manual

- tap paragraph to edit in place
- tap image delete button removes image block and underlying Markdown
- insert code block opens the new block in edit mode
- tap code block delete button removes the fenced block
- switch between blocks with unsaved edits and confirm source stays correct
- send a mixed message containing paragraph + image + code block

### Automated

Add focused tests around:

- Markdown block parsing for paragraph/image/code
- delete operation removing the correct source range
- insert-after-active-block behavior
- flush-before-send behavior

UI tests are valuable if the existing project has a pattern for widget tests in this area, but block parser/controller tests should come first.

## Open Implementation Notes

- Reuse `MarkdownRenderer` for preview rendering wherever practical.
- Keep accessibility labels on icon buttons and delete controls.
- Preserve current media insertion/upload helpers; only the presentation and block insertion behavior changes in phase 1.
- `chat_page.dart` should be slimmed down by moving composer logic into dedicated widgets/controllers rather than growing the file further.