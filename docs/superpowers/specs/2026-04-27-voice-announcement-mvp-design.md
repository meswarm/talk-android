# Voice Announcement MVP Design

## Goal

Add the first minimal version of a global voice announcement role for the mobile app. This version is only a "voice announcer": when a qualifying new Matrix message arrives, the app speaks a short notification sentence.

The MVP should prove the end-to-end chain:

Matrix message event -> notification filtering -> fixed announcement text -> Doubao TTS -> local audio playback.

It does not summarize messages, read message bodies, understand voice commands, or act on the user's behalf.

## Product Scope

The user can open a new settings entry named "语音播报" from the profile page. The settings page stores local Doubao TTS configuration and controls whether new-message voice announcements are enabled.

The first version includes these settings:

- Enable new-message voice announcement.
- Doubao API Key.
- Resource ID, defaulting to `seed-tts-2.0`.
- Speaker ID.

Credentials are stored on the device using OS-backed secure storage, matching the current R2 credential model. This is acceptable for a personal MVP. A future production multi-user deployment should move TTS calls behind a backend proxy so the provider key is not distributed in the client.

## Announcement Behavior

Voice announcement reuses the existing notification eligibility rules in `NotificationService`:

- Ignore non-message Matrix events.
- Ignore messages sent by the current user.
- Ignore messages for the room currently open in the UI.
- Ignore empty message bodies.

When a message passes these checks and voice announcement is enabled, the app speaks a short fixed sentence. The first version does not speak message content.

Initial template:

```text
你有一条来自{senderName}的新消息
```

Group-room phrasing is intentionally out of the first implementation. A later version can switch group rooms to:

```text
{roomName}里，{senderName}发来一条新消息
```

The MVP uses the single template for all rooms.

## Architecture

Add a small Doubao TTS module rather than putting TTS logic inside notification code:

- `DoubaoTtsConfig`: local configuration model.
- `DoubaoTtsCredentialStore`: reads and writes config in `FlutterSecureStorage`.
- `DoubaoTtsService`: loads config, exposes enabled state, requests TTS audio, and plays announcements.
- `VoiceAnnouncementSettingsPage`: profile-linked settings UI.

`NotificationService` remains responsible for deciding whether a message should notify. After it prepares the system notification payload, it calls the TTS service with the announcement text. TTS failures must not block or break system notifications.

## Doubao API

Use the HTTP Chunked one-way streaming V3 endpoint from `doubao2.md`:

```text
POST https://openspeech.bytedance.com/api/v3/tts/unidirectional
```

Required headers for the new console authentication path:

```text
X-Api-Key: <configured API key>
X-Api-Resource-Id: <configured resource id>
X-Api-Request-Id: <generated request id>
```

The request body includes the text, speaker, and audio parameters. For the MVP:

- Audio format: `mp3`.
- Sample rate: `24000`.
- Speech rate: default `0`.
- Loudness rate: default `0`.
- Subtitle and timestamp features disabled.

The response is a chunked JSON stream. The app reads each JSON chunk, extracts base64 audio payloads, decodes them, concatenates the bytes, and plays the resulting MP3 bytes through the existing audio playback dependency.

## Error Handling

Missing or disabled TTS configuration means voice announcement is skipped silently.

Network, authentication, malformed response, and playback failures are logged or surfaced only in the settings/test path. During normal message notification handling, failures are swallowed so text notifications still work.

If multiple messages arrive quickly, the MVP should avoid overlapping speech. A simple serialized queue is enough: finish the current announcement before playing the next one. If this becomes noisy, a later version can debounce by room or collapse multiple messages into one announcement.

## UI

Profile page adds one list item:

```text
语音播报
```

The settings page explains briefly that the API Key is stored only on this device. Fields are editable, masked where appropriate, and include save/clear actions similar to the R2 settings page.

The settings page includes a "测试播报" button. The test phrase is:

```text
语音播报已开启
```

## Testing

Unit tests should cover:

- TTS config JSON round trip.
- Missing or malformed stored config returns no config.
- Announcement text builder returns the expected fixed template.
- Notification integration does not throw when TTS is disabled or fails.

Widget tests should cover:

- Profile page exposes the "语音播报" entry.
- Settings page validates required API Key and speaker fields.
- Save and clear actions call the expected service/store behavior.

Manual verification should cover:

- Save Doubao settings on a device or emulator.
- Send a Matrix message from another account.
- Confirm a system notification still appears.
- Confirm the app speaks the fixed announcement.
- Confirm no announcement happens inside the currently open room.

## Out Of Scope

- Reading full message content aloud.
- Summarizing messages with an LLM.
- Voice command input, ASR, or conversational secretary behavior.
- Backend proxy for TTS credentials.
- Per-room or per-contact voice announcement rules.
- Do-not-disturb scheduling.
- Custom emotional style controls beyond the configured speaker.
