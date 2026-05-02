# Room Auto Collapse Design

## Summary

This spec adds a room-level quick toggle in the chat page AppBar for controlling whether long text messages in the current room should auto-collapse.

The agreed first version is:

- the toggle lives in the top-right AppBar slot highlighted by the user
- the toggle only affects the current room
- the preference is stored locally on this device
- the default for every room is `enabled`
- when enabled, long text / Markdown bubbles keep using the existing auto-collapse behavior
- when disabled, long text / Markdown bubbles render fully expanded without height-based auto-collapse
- media messages are out of scope for this toggle

This design keeps the current global bubble-height setting, but adds a room-specific on/off override for whether that collapse system should be applied at all.

## Goals

- Let users quickly disable auto-collapse in rooms where replies are usually short.
- Keep auto-collapse enabled by default for rooms with consistently long answers.
- Make the control immediate and room-local, without sending any setting to the server.
- Reuse the existing text-bubble collapse system instead of inventing a parallel rendering path.
- Preserve the current global bubble max-height preference as the collapse threshold when room auto-collapse is enabled.

## Non-Goals

- Per-room custom collapse height percentages.
- Syncing the setting across devices or accounts.
- Applying the room toggle to image, video, audio, or file bubbles.
- Reworking the global bubble-height settings UI.
- Batch editing multiple rooms at once.

## Current State

Long text / Markdown bubble collapse currently works like this:

- `MessageBubble` computes `bubbleMaxH` from the global `BubbleMaxHeightProvider`
- text messages are rendered through `ExpandableMarkdownBody`
- `ExpandableMarkdownBody` measures overflow, clips to `maxHeight`, and shows the expand / collapse bar when needed

Today this behavior is global-only. There is no way to say "this room should not auto-collapse" while preserving auto-collapse in other rooms.

## User Experience

### AppBar Entry

The new control lives in the AppBar action row for joined rooms, in the top-right position the user identified.

Behavior:

- tap once to toggle the current room between auto-collapse enabled / disabled
- no confirmation dialog
- the icon updates immediately
- a lightweight `SnackBar` confirms the new state

Suggested tooltip copy:

- enabled state: `关闭当前房间的自动折叠`
- disabled state: `开启当前房间的自动折叠`

Suggested user-facing feature label:

- `自动折叠长消息`

### Bubble Behavior When Enabled

When room auto-collapse is enabled:

- text / Markdown bubbles behave exactly like today
- long content is clipped to the global collapse height threshold
- the bottom fade and expand bar appear when overflow exists
- users can still manually expand and collapse each message

### Bubble Behavior When Disabled

When room auto-collapse is disabled:

- text / Markdown bubbles render their full content
- no height-based clipping occurs
- the expand / collapse bar is not shown
- media messages remain unchanged

### Defaulting Rules

For any room with no stored preference:

- room auto-collapse defaults to `true`

This matches the user's preferred conservative default: rooms start with collapse enabled, and users selectively turn it off in rooms that usually contain short content.

## Technical Design

### 1. Local Storage

Add a room-scoped local preference in `LocalStorage`.

Recommended API:

- `loadRoomAutoCollapseEnabled(String roomId)`
- `saveRoomAutoCollapseEnabled(String roomId, bool enabled)`

Recommended storage model:

- persist one bool per room ID using a dedicated prefix
- return `true` when the key is absent

This should follow the same room-scoped local-storage pattern already used for room notes.

### 2. ChatPage State

`ChatPage` owns the current room's toggle state.

Recommended state and helpers:

- `_roomAutoCollapseEnabled`
- `_loadRoomAutoCollapsePref()`
- `_toggleRoomAutoCollapse()`

Lifecycle:

- load the preference during `initState()`
- optionally reload it in `didPopNext()` for future-proofing, similar to room-note refresh
- when toggled, update local state immediately, then persist asynchronously

The AppBar button should be available only for normal joined-room chat pages, matching the existing room-note and invite-user action rules.

### 3. MessageBubble Wiring

`MessageBubble` should receive the room-level auto-collapse decision and pass it into the text-body renderer.

Recommended shape:

- add a boolean field such as `autoCollapseEnabled`
- use it only for text / Markdown rendering

`MessageBubble` continues to use the existing global `bubbleMaxH` as the threshold, but only when `autoCollapseEnabled == true`.

### 4. ExpandableMarkdownBody Contract

`ExpandableMarkdownBody` should explicitly support a boolean like:

- `autoCollapseEnabled`

Behavior contract:

- when `true`: preserve current overflow measurement, clipping, fade overlay, and expand / collapse controls
- when `false`: render Markdown directly without overflow measurement, clipping, or toggle UI

This is preferred over passing an artificially huge `maxHeight`, because the component behavior stays explicit and easier to reason about.

### 5. Global And Room Responsibilities

Responsibilities should stay separate:

- global bubble max-height preference: defines the collapse threshold
- room auto-collapse toggle: defines whether the current room uses collapse at all

This keeps the architecture understandable:

- global setting answers "how tall may a collapsed bubble be?"
- room setting answers "should this room auto-collapse long bubbles?"

## Icon And Feedback

Recommended first-version icon pair:

- enabled: `Icons.unfold_less`
- disabled: `Icons.unfold_more`

Rationale:

- the semantics are closer to "compact / fully expanded message display" than generic settings icons
- they fit the AppBar action area without additional text

Recommended `SnackBar` copy:

- `已开启当前房间自动折叠`
- `已关闭当前房间自动折叠`

## Testing

### Local Storage

Add tests that verify:

- missing key returns `true`
- saving `false` for a room reads back as `false`
- values are isolated across different room IDs

### ExpandableMarkdownBody

Add tests that verify:

- when `autoCollapseEnabled == false`, full content renders with no expand / collapse control
- when `autoCollapseEnabled == true` and content overflows, the collapsed UI still appears

### Chat Page / Bubble Integration

Add focused widget tests that verify:

- the AppBar toggle appears for joined rooms
- tapping the toggle updates the icon and persists the value
- a long message in a room with auto-collapse disabled does not show collapse controls
- re-entering the same room restores the saved room-specific preference

## Risks And Guardrails

- Do not couple this room setting to server state; it is intentionally local-only.
- Do not let the room toggle mutate or replace the existing global bubble-height preference.
- Do not broaden the first version to media bubbles; keep scope limited to text / Markdown.
- Avoid hidden behavior based on oversized `maxHeight` hacks; prefer an explicit boolean contract.

## Open Questions Resolved

- Entry location: the AppBar slot marked by the user.
- Interaction style: direct one-tap quick toggle, not a navigation entry.
- Default value: enabled.
- Scope: current room only, locally persisted.
- Content scope: text / Markdown bubbles only.

## Acceptance Criteria

The feature is complete when:

1. Joined-room chat pages show a room-level AppBar toggle for auto-collapsing long messages.
2. A room with no saved preference behaves as auto-collapse enabled.
3. Disabling the toggle in one room stops long text / Markdown bubbles from auto-collapsing in that room only.
4. Re-enabling the toggle restores the existing collapse behavior in that room.
5. Other rooms keep their own independent preferences.
6. Global bubble-height settings continue to define the collapse threshold whenever room auto-collapse is enabled.