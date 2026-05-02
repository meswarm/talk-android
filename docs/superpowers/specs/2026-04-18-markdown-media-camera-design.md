# Markdown Media Library And Camera Design

## Summary

This design updates the expanded mobile Markdown composer so media insertion feels closer to a chat app workflow while staying intentionally small in scope for the first version.

The new behavior is:

- Toolbar entry 1 becomes a unified media-library entry for choosing either an existing image or an existing video.
- Toolbar entry 2 becomes an in-app camera entry.
- The camera page supports tap-to-photo and press-and-hold-to-record-video.
- Video capture stops on release or when the 15-second limit is reached.
- After capture, the user reviews the result and confirms insertion.
- Confirmed media is normalized, uploaded to R2 through the existing path, and inserted into the Markdown source at the current selection.

Out of scope for v1:

- cropping
- filters
- trimming
- multi-clip video
- stickers, captions, or advanced editing

## Goals

- Preserve the existing Markdown editing workflow and current R2-backed insertion model.
- Separate "pick existing media" from "capture new media" so the UI remains obvious.
- Provide a WeChat-like interaction model for camera capture without building a heavy media editor.
- Keep implementation boundaries clear so image and video insertion share one upload-and-insert pipeline.

## Non-Goals

- Replacing the normal collapsed composer media behavior.
- Adding a new Markdown media format.
- Supporting long-form video capture.
- Building desktop-specific camera interactions.

## User Experience

### Toolbar

In the expanded Markdown composer toolbar:

- Entry 1 changes from `image` to `media library`.
- Entry 2 changes from `video` to `camera`.
- Audio, file, code block, preview, clear, and collapse actions stay as they are.

The media-library entry opens a lightweight choice flow:

- choose image
- choose video

This keeps the existing "pick from device" mental model while avoiding two separate adjacent buttons for image and video.

### Camera Page

The camera entry opens a dedicated in-app camera page. The page stays intentionally minimal.

Capture behavior:

- tap shutter: capture a photo
- press and hold shutter: start video recording
- release shutter: stop video recording
- auto-stop recording at 15 seconds

The page should also include:

- close / cancel
- front-back camera switch if supported
- simple recording timer while video is active

No advanced editing controls are included in v1.

### Review Page / Review State

After capture:

- photo -> show still preview
- video -> show short video preview or representative first frame with playback affordance

Available actions:

- retake
- insert into Markdown

Insertion does not happen directly inside the camera page logic. The page returns a structured capture result to the composer host, and the existing upload-and-insert flow handles the rest.

## Technical Design

### 1. Toolbar API changes

Current toolbar callbacks are split by image and video. The first version should move toward intent-based callbacks:

- `onPickMediaLibrary`
- `onOpenCameraCapture`

The existing upload callbacks for audio and file remain unchanged.

`MobileMarkdownComposer` and `MarkdownComposerToolbar` should be updated together so the toolbar remains a simple event emitter and does not own picker or camera logic.

### 2. Composer host coordination

`chat_page.dart` currently owns the expanded composer and already coordinates image/video picking plus Markdown insertion. That page should continue to be the orchestration layer.

It becomes responsible for:

- opening the media-library chooser
- opening the custom camera page
- receiving a structured media result from either path
- normalizing the file
- uploading through existing R2 logic
- inserting Markdown into the current editor selection

This keeps all insertion side effects in one place and avoids duplicating "upload then insert" logic inside the camera page.

### 3. New camera page

Add a new page dedicated to capture, for example:

- `lib/pages/camera_capture_page.dart`

The page should expose a result object back to the caller, for example:

- media type: image or video
- local file path
- mime type
- optional width / height
- optional duration for video

The page should manage only capture-oriented state:

- initializing camera
- previewing
- recording
- reviewing photo
- reviewing video
- capture failure state

It should not manage R2 upload or Markdown insertion.

### 4. Media normalization layer

Before upload, both library-picked and camera-captured media should pass through a shared normalization step.

For images:

- resize long edge to a moderate chat-friendly size
- compress to JPEG or equivalent chat-friendly output

For videos:

- enforce max duration 15 seconds
- reduce resolution / bitrate to a moderate range
- reject unsupported or invalid output early

The exact compression package can be chosen during planning, but the design requires that captured media should not upload at original unrestricted quality by default.

### 5. Existing R2 insertion path

The project already uploads media to R2 and inserts Markdown snippets. That path should remain canonical.

The new work should reuse the same:

- R2 credential checks
- upload progress / busy state
- Markdown media snippet generation
- editor insertion behavior

This avoids introducing a second media format or a parallel preview stack.

## Data Flow

### Media library flow

1. User taps media-library button.
2. User chooses image or video.
3. System picker returns a file.
4. File is normalized if needed.
5. File uploads to R2.
6. Resulting Markdown snippet is inserted at the current selection.

### Camera flow

1. User taps camera button.
2. App opens the in-app camera page.
3. User taps to capture a photo, or presses and holds to record a video.
4. User reaches review state.
5. User taps insert.
6. Camera page returns the capture result to the composer host.
7. Composer host normalizes the file if needed.
8. Composer host uploads to R2.
9. Composer host inserts the Markdown snippet into the editor.

## Error Handling

### Permissions

The UI must explicitly handle:

- camera permission
- microphone permission for video recording
- media-library permission where required by platform

If microphone permission is missing during long-press video capture, recording should not start and the user should see a clear explanation.

### Capture failures

The camera page should provide recoverable failure behavior for:

- camera initialization failure
- photo capture failure
- video recording start failure
- video recording stop failure

Recovery should prefer retrying or leaving the page, not trapping the user in a broken state.

### Validation failures

Reject early when:

- file path is missing
- media file is empty
- video duration exceeds 15 seconds
- mime type is unsupported

### Upload failures

If R2 is not configured or upload fails:

- keep the editor text unchanged
- show a clear error
- do not insert a broken Markdown snippet

Persisting a retry queue is not required for v1.

## Testing Strategy

### Logic tests

- Markdown insertion at caret / selection still works with returned media results.
- Video duration over 15 seconds is rejected.
- Media-library and camera flows route into the same insertion pipeline.

### Widget tests

- Toolbar exposes the renamed first and second actions.
- Camera page transitions between preview, recording, and review states correctly.
- Confirm and retake actions appear in the expected states.

### Manual device verification

- tap captures photo
- long press starts recording
- release stops recording
- recording auto-stops at 15 seconds
- photo inserts successfully
- short video inserts successfully
- permission denial states are understandable
- R2 misconfiguration surfaces a useful error

## Implementation Notes

- Build the happy path in stages:
  1. rename toolbar actions and merge library image/video entry
  2. add camera page shell
  3. wire photo capture end to end
  4. wire video capture end to end
  5. add duration limits, error messages, and polish
- Keep the first version mobile-focused and avoid speculative desktop abstractions.

## Open Decisions Deferred To Planning

- exact camera plugin and lifecycle handling strategy
- exact image/video compression packages and target dimensions
- whether video preview in review state should autoplay or remain paused
- whether the media-library entry should use a custom bottom sheet or native picker first