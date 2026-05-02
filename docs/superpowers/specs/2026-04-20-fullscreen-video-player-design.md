# Fullscreen Video Player Design

## Summary

This spec adds a dedicated fullscreen video player for chat videos so users can watch message videos more clearly than the current inline bubble playback allows.

The agreed first-version experience is:

- chat video bubbles show a thumbnail or first frame, a central play button, and a duration label
- only tapping the play button opens the fullscreen player
- entering the fullscreen player automatically starts playback
- the fullscreen page provides play / pause, current time, total duration, and a draggable seek bar
- single tap on the video area toggles the playback controls
- exiting the page stops playback and releases player resources

The design intentionally keeps the first version small and stable. Inline bubble playback is replaced by a clearer “enter fullscreen to watch” model.

## Goals

- Make chat videos easier to watch by moving playback out of the scrolling message list.
- Match the user's preferred entry rule: only the play button should open the fullscreen player.
- Keep the fullscreen UI minimal and focused on the video itself.
- Reuse existing `video_player` capabilities instead of introducing a heavier playback stack.
- Keep architecture ready for future reuse by other video surfaces without requiring that reuse in v1.

## Non-Goals

- Inline playback controls inside the chat bubble.
- Double-tap seek, gesture seek, playback speed, mute, or volume gestures.
- Automatic landscape rotation or orientation locking in v1.
- Picture-in-picture, playlists, or multi-video browsing.
- Markdown video integration in the first implementation.

## Current State

Chat videos are currently rendered inline in `lib/widgets/event_media_content.dart`:

- the attachment is downloaded to a temporary local file
- `VideoPlayerController.file(...)` is created in the message widget
- the bubble renders an inline `VideoPlayer`

This is acceptable for small previews but not ideal for real viewing because:

- the video competes with chat scrolling and adjacent messages
- the available viewport is constrained by bubble sizing
- playback state lives inside the message list instead of a dedicated viewing surface
- controls for seeking and clearer playback are not presented as a focused experience

`lib/widgets/r2_markdown_video.dart` also renders inline playback for Markdown video previews, but that path is out of scope for this first version.

## User Experience

### Bubble Presentation

The chat bubble should no longer behave like a mini player.

Instead, the video bubble should show:

- a thumbnail or the first available video frame
- a prominent centered play button
- a duration badge in a corner

Interaction rules:

- tapping the play button opens the fullscreen player
- tapping any other part of the video card does nothing
- the bubble itself does not start inline playback

This keeps the entry rule explicit and avoids accidental fullscreen opens.

### Fullscreen Layout

The fullscreen player uses a dark immersive layout aligned with the image viewer style.

Layout rules:

- background: black or near-black
- main video region: centered and aspect-ratio correct
- top bar: minimal, with back and a simple title
- bottom bar: minimal playback controls only

The video should not be stretched. Black bars are acceptable when aspect ratio does not match the screen.

### Entering Playback

When the user taps the bubble play button:

1. the app opens a dedicated fullscreen video page
2. the page initializes the player if needed
3. playback starts automatically as soon as initialization succeeds

If initialization is still in progress, the page shows a loading state on a dark background.

### Controls

The fullscreen controls should stay intentionally small in scope.

Required controls:

- play / pause button
- current time label
- total duration label
- draggable progress bar for seeking

Control visibility behavior:

- controls are visible on initial entry
- single tap on the video area toggles controls on or off
- while playing, controls may auto-hide after a short idle delay
- while paused, controls remain visible
- while the user is dragging the seek bar, controls remain visible

### Seek Behavior

The seek interaction should prioritize predictability.

Rules:

- dragging the progress bar enters a seeking state
- while dragging, the current-time label updates to reflect the drag position
- on release, the player seeks to the selected position
- if playback was active before dragging, playback resumes after seek completes
- if playback was paused before dragging, the player stays paused after seek completes

### Playback Completion

When the video reaches the end:

- playback stops
- the final frame may remain visible
- controls become visible
- the play button returns to the “play” state

When the user presses play again after completion, playback should restart from the beginning.

### Exit

The first version keeps exit behavior simple:

- top-left back button
- system back gesture / back button

On exit:

- stop playback
- dispose the `VideoPlayerController`
- release any temporary-file-backed resources owned by the page

## Technical Design

### 1. Dedicated Fullscreen Player Page

Introduce a dedicated page widget for fullscreen playback, for example:

- `lib/pages/fullscreen_video_player_page.dart`

The page owns fullscreen-only concerns:

- player lifecycle for the fullscreen session
- control visibility
- play / pause state
- seek state
- loading and failure state

It should not own chat list orchestration beyond receiving the resolved video source needed to play.

### 2. Bubble And Player Separation

Split responsibilities clearly:

- bubble widget: preview only
- fullscreen page: actual playback

The bubble should not own long-lived playback logic in v1. This reduces state conflicts and keeps the chat list lighter.

### 3. Video Source Model

The fullscreen player should accept a normalized video source abstraction that is simple enough for current chat attachments.

For v1, the most practical source form is:

- local file path

This matches the current attachment flow in `EventMediaContent`, which already materializes message videos into a temporary local file before playback.

Optional metadata that can travel with the source:

- hero or transition tag, if a visual transition is desired later
- duration hint, if available
- title label, if useful for future UI

The first version does not need multiple source kinds unless implementation planning identifies an immediate need.

### 4. Controller Lifecycle

The fullscreen page should create and own its own `VideoPlayerController`.

Required lifecycle behavior:

- initialize controller on page entry
- set non-looping playback in v1
- auto-play on successful initialization
- observe playback position and duration for control updates
- dispose controller on exit

This page-local ownership avoids coupling fullscreen playback to the bubble widget's controller state.

### 5. Bubble Preview Strategy

The bubble should show a static preview instead of inline playback.

Preferred v1 approach:

- reuse the resolved video controller long enough to display the first frame if already available
- otherwise show a neutral dark thumbnail with play affordance until preview is ready

The exact thumbnail strategy can be finalized during implementation planning, but the visible result must be:

- a non-playing preview surface
- a clear play button
- a duration label

### 6. Fullscreen Control State

The page needs a small set of local state:

- controller readiness
- current playing / paused status
- current position
- total duration
- controls visible / hidden
- whether a seek drag is in progress
- whether playback was active before seek drag started

This state should remain local to the fullscreen page and should not leak back into the chat bubble.

### 7. Failure States

The fullscreen player must handle:

- loading / initialization
- playback initialization failure
- seek failure

Failure UI should remain lightweight:

- concise error text
- reliable back navigation

The page should not leave the user stuck in an unusable playback state.

## Data Flow

### Chat video flow

1. Message bubble resolves the video attachment to a local temporary file as it already does today.
2. The bubble renders a preview surface with play button and duration.
3. User taps the play button.
4. The app opens the fullscreen video player page with the resolved local file path.
5. The fullscreen page initializes its own controller.
6. Playback starts automatically.
7. User watches, pauses, seeks, and exits within the fullscreen page.

## Risks And Mitigations

### Duplicate controller ownership

Risk:

- inline bubble playback and fullscreen playback can drift into two competing controller owners

Mitigation:

- make the bubble preview-only
- move actual playback responsibility to the fullscreen page

### Control visibility conflicts

Risk:

- auto-hide, single-tap toggle, and seek interactions can produce confusing control visibility

Mitigation:

- keep the rules simple
- show controls on entry
- keep controls visible while paused or actively seeking

### Temporary file lifecycle

Risk:

- local file cleanup may be forgotten or tied to the wrong owner

Mitigation:

- define explicit ownership in implementation planning
- ensure the page disposes the controller and cleans page-owned resources on exit

### Scope creep

Risk:

- video playback features can expand quickly into a full media player project

Mitigation:

- keep v1 limited to play / pause, seek bar, time labels, and back navigation

## Testing Strategy

- widget tests for opening the fullscreen player from a bubble play button
- widget tests for control visibility toggling
- widget tests for play / pause state changes
- widget tests for seek bar interactions and resume / stay-paused behavior
- manual verification on a real chat video attachment
- `flutter analyze` and `flutter test` before completion

## Success Criteria

- chat video bubbles no longer act as inline players
- only tapping the play button opens fullscreen playback
- entering fullscreen starts playback automatically
- users can pause and resume playback
- users can drag the progress bar to seek to another time
- exiting fullscreen releases playback resources cleanly
