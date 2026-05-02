# Fullscreen Image Viewer Design

## Summary

This spec adds a dedicated fullscreen image viewer for chat images so users can inspect dense screenshots, receipts, policies, and other small-text images more comfortably on mobile.

The agreed first-version experience is:

- tapping an image inside a message bubble opens a dedicated fullscreen viewer page
- the image initially displays as the full image, centered and uncropped
- users can single-tap to toggle the top toolbar
- users can double-tap to zoom in and double-tap again to return to the base scale
- users can pinch to zoom and drag when zoomed in
- the viewer supports two display modes: `fit screen` and `fit width`

The design intentionally favors a stable and readable first version over feature breadth.

## Goals

- Make image-heavy chat messages easier to inspect without fighting the chat list layout.
- Preserve the user's preferred default: show the full image first, then allow zooming for detail.
- Keep the fullscreen UI visually quiet so the image gets most of the screen.
- Provide one reusable viewer path that can later serve both message attachments and Markdown-rendered images.

## Non-Goals

- Building a multi-image gallery in v1.
- Adding swipe-to-dismiss in v1.
- Adding OCR, annotation, or image editing tools.
- Adding save/share/export actions in the first implementation.
- Supporting desktop-specific viewer interactions beyond normal Flutter defaults.

## Current State

Chat images are currently rendered inline inside the message bubble or Markdown surface:

- `lib/widgets/event_media_content.dart` renders `m.image` attachments directly with `Image.memory`
- `lib/widgets/r2_markdown_image.dart` renders R2-backed Markdown images inline
- `lib/widgets/markdown_renderer.dart` renders network and asset Markdown images inline

The current experience keeps images inside the message flow, which is fine for casual viewing but not ideal for reading small text because:

- the available viewport is constrained by bubble sizing and surrounding chat UI
- there is no dedicated fullscreen interaction model
- image inspection competes with list scrolling and adjacent message content

## User Experience

### Entry Point

Users open the viewer by tapping an image shown in a chat message.

The entry should feel like the image expands out of the chat surface. If practical within the existing widget structure, use a lightweight shared-element / `Hero` style transition. If that adds too much complexity for the first pass, a normal page push is acceptable.

### Fullscreen Layout

The fullscreen viewer uses a dark immersive background and a minimal top toolbar.

Layout rules:

- the image gets the dominant visual area
- the top toolbar contains only:
  - back
  - display-mode switch entry
  - more-actions entry reserved for future expansion
- no persistent bottom toolbar in v1
- any hint text should be lightweight and non-blocking

The toolbar should be allowed to hide so the image can occupy as much of the display as possible.

### Default Presentation

On entry, the viewer should show the complete image rather than zooming to a crop.

Default behavior:

- background: dark
- base image alignment: centered
- base fit: equivalent to `BoxFit.contain`
- no initial crop
- no initial zoom beyond the selected base display mode

This matches the user's preference to first preserve the whole image and then zoom in only when needed.

### Gestures

#### Single tap

- toggles the top toolbar visibility

#### Double tap

- if currently at base scale, zoom to a preset scale around the tapped point
- if already zoomed in, return to the base scale and base position

Recommended initial zoom target:

- around `2.2x`

#### Pinch

- continuously zooms in or out
- minimum scale is the active base scale
- maximum scale is capped in v1

Recommended initial maximum scale:

- `4.0x`

#### Drag / pan

- enabled only when current scale is greater than the active base scale
- used to inspect zoomed content
- when at base scale, the image should remain stable and centered instead of drifting

### Display Modes

The viewer supports exactly two modes in v1.

#### Mode 1: Fit Screen

- default mode on open
- the whole image is visible if possible
- best for quickly understanding the full image composition

#### Mode 2: Fit Width

- optional user-selected mode
- image width expands to the available screen width
- especially useful for long screenshots and dense vertical documents

When switching display modes:

- reset zoom and pan state
- recompute the base transform for the newly selected mode

This avoids confusing transitions where the image remains offset or zoomed from the previous mode.

### Exit

The first version keeps exit behavior intentionally simple:

- top-left back button
- system back gesture / back button

Swipe-to-dismiss is explicitly deferred because it is likely to conflict with zoomed panning and would make the first version harder to stabilize.

## Technical Design

### 1. Dedicated Viewer Page

Introduce a dedicated page widget for fullscreen viewing, for example:

- `lib/pages/fullscreen_image_viewer_page.dart`

The page should accept a single normalized image source plus light metadata needed for display and hero coordination.

The page owns only fullscreen-viewer concerns:

- display mode
- zoom / pan state
- toolbar visibility
- loading and error state

It should not own chat-message orchestration or media downloading policy beyond what is needed to display the given image source.

### 2. Unified Open-Viewer Entry

Do not scatter fullscreen-preview logic independently across each image renderer.

Instead, introduce one reusable viewer-opening path, such as:

- a helper function
- a route builder
- or a small coordinator widget / utility

The important design requirement is that both of these should be able to converge on the same viewer implementation:

- message attachment images from `EventMediaContent`
- Markdown-rendered images from `R2MarkdownImage` and `MarkdownRenderer`

This keeps gestures, visual style, error handling, and future features consistent.

### 3. Image Source Model

The viewer should work with a small normalized source abstraction rather than duplicating code for every upstream image type.

Examples of supported source forms:

- in-memory bytes
- network URL
- asset path

The exact type can be chosen during planning, but the abstraction must be simple enough that current image surfaces can adapt into it without bespoke fullscreen pages per source type.

### 4. Base Transform Strategy

The viewer needs a clear distinction between:

- the active base presentation (`fit screen` or `fit width`)
- user-applied zoom above that base

This distinction matters because `1.0` in interaction code should mean "base state for the active mode", not "always contain mode regardless of current mode."

Implementation-wise, this can be done with:

- `InteractiveViewer` plus explicit transform resets
- or a dedicated zoomable image package if implementation planning shows that double-tap-to-point and base-mode management are meaningfully easier there

The spec does not force a package choice, but it does require:

- base mode reset on mode switch
- double-tap zoom around the tap location
- stable centered image at base scale

### 5. Loading And Failure States

The viewer must behave gracefully for non-instant image sources.

Required states:

- loading: show a centered progress indicator on a dark background
- failure: show a concise error message and retain a reliable way to go back

The failure state should remain visually lightweight and should not trap the user.

### 6. Future-Reserved Actions

The minimal top-right `more` entry is intentionally included even if its first implementation is hidden or contains only non-destructive actions.

It reserves UI space for future capabilities such as:

- save image
- share image
- view original
- inspect metadata

If an empty menu feels awkward in implementation, the icon may be hidden in v1, but the layout and page structure should make room for adding it later without redesigning the page.

## Data Flow

### Attachment image flow

1. User taps an image attachment in a message bubble.
2. The current image surface adapts the image into the normalized fullscreen image source.
3. The app opens the fullscreen viewer page.
4. The viewer renders the image in `fit screen` mode by default.
5. User interacts with zoom, pan, and mode switching locally inside the viewer page.

### Markdown image flow

1. User taps a Markdown-rendered image.
2. The Markdown image widget adapts its source into the same normalized fullscreen image source.
3. The app opens the same fullscreen viewer page.
4. The rest of the interaction flow remains identical.

## Risks And Mitigations

### Gesture conflicts

Risk:

- zoom, pan, double-tap, and dismissal-style gestures can interfere with each other

Mitigation:

- keep v1 gesture scope small
- exclude swipe-to-dismiss from v1
- only allow panning above base scale

### Divergent image source handling

Risk:

- attachment images and Markdown images could drift into separate preview implementations

Mitigation:

- require a shared fullscreen page
- normalize image sources at the boundary

### Confusing mode switching

Risk:

- users may get lost if `fit width` preserves an old zoom/pan offset

Mitigation:

- fully reset transform state when switching display modes

### Large-image performance

Risk:

- large images may cause slow first paint or heavy memory use

Mitigation:

- keep the first version focused on straightforward display
- ensure loading and failure states are explicit
- prefer incremental optimization during implementation if profiling reveals specific issues

## Testing Strategy

- widget tests for opening the viewer from at least one image surface
- widget tests for toolbar visibility toggle
- widget tests for display mode switching and transform reset behavior
- widget tests or focused interaction tests for double-tap zoom/reset behavior
- manual verification on a dense screenshot / small-text image
- `flutter analyze` and `flutter test` before completion

## Success Criteria

- tapping a chat image opens a dedicated fullscreen viewer
- the viewer initially shows the full image rather than a cropped portion
- users can zoom and inspect details without the chat list interfering
- users can switch between `fit screen` and `fit width`
- the layout remains visually minimal and image-first
- the implementation path is reusable for both message attachments and Markdown-rendered images
