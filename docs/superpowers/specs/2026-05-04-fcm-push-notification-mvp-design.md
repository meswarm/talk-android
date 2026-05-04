# FCM Push Notification MVP Design

## Goal

Build the smallest Android push-notification path that can show a system notification even when the Talk Flutter process has been reclaimed by Android.

## Scope

This MVP is app-side only. It does not implement the Talk server push gateway yet. The app will integrate Firebase Cloud Messaging, expose the current device FCM token in a settings page, handle foreground messages by showing a local notification, and route notification taps to the target room when the room is available locally.

Out of scope for this MVP:

- Real-time voice calls.
- Server-side Matrix-to-FCM fanout.
- Voice announcement from background FCM handlers.
- Guaranteed delivery after the user manually taps Android Settings > Force stop. Android intentionally blocks app wakeups in that state until the user opens the app again.

## Architecture

The implementation uses Firebase Messaging as the Android wakeup and delivery layer. `NotificationService` remains the single system-notification presenter so Matrix live-sync notifications and FCM notifications share one notification channel and tap behavior.

The app adds a small push module:

- `FcmPushPayload` parses Firebase message notification/data fields into app-level fields.
- `FcmPushService` wraps Firebase Messaging startup, token retrieval, foreground message listening, and notification-open handling.
- A `PushNotificationSettingsPage` shows whether FCM is available, the token, and a local test notification button.

## Message Contract

For MVP testing, use a Firebase notification message with data:

```json
{
  "notification": {
    "title": "房间名",
    "body": "发送者: 消息摘要"
  },
  "data": {
    "roomId": "!room:example.com",
    "eventId": "$event",
    "senderName": "Alice"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "talk_messages"
    }
  }
}
```

Notification payload is preferred for the first MVP because Android can display it from Google Play services even when the app process is not running. The data fields are used for opening the room after the user taps the notification. Data-only high-priority messages are intentionally deferred because they require stricter background-handler behavior and are less useful for this first "system notification appears" milestone.

## Error Handling

If Firebase is not configured, the app must not crash. The settings page shows a clear "未配置 Firebase" state. If token retrieval fails, the error is shown in the settings page and existing Matrix in-app notifications continue working.

If a notification tap contains a `roomId` that is not currently known to the Matrix client, the app opens normally and ignores the room navigation instead of throwing.

## Verification

Automated verification covers payload parsing, FCM service state with a fake messaging client, settings page rendering, and notification tap routing. Manual verification uses Firebase Console or HTTP v1 to send a notification with `roomId` while the app is foregrounded, backgrounded, and killed by the system or removed from recents. Do not use Android "Force stop" as a success criterion because FCM is not reliable by design after force-stop.
