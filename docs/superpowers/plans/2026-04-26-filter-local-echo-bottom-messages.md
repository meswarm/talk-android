# Filter Local Echo Bottom Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop stale Matrix local echo events from permanently appearing at the bottom of Android chat rooms.

**Architecture:** Keep the chat UI layout unchanged and fix the problem in the timeline display filter. Matrix SDK stores pending/error local echo events before synced events; because the chat `ListView` is reversed, those stale local echoes appear at the visual bottom. Filter current-user, non-synced events before rendering while preserving synced server events and repeated real messages.

**Tech Stack:** Flutter, Dart, `matrix` SDK, `flutter_test`.

---

## File Structure

| Path | Responsibility |
|------|----------------|
| `lib/matrix/timeline_messages.dart` | Timeline display filtering and local echo suppression. |
| `test/matrix/timeline_messages_test.dart` | Unit tests for timeline filtering behavior. |

No UI files should change for this fix. In particular, do not change `lib/pages/chat_page.dart` `ListView(reverse: true)` or scroll behavior.

---

### Task 1: Add Regression Tests for Stale Local Echo Events

**Files:**
- Modify: `test/matrix/timeline_messages_test.dart`

- [ ] **Step 1: Add failing tests after `timelineMessagesForDisplay hides persisted own sent local echo`**

Add these tests:

```dart
  test('timelineMessagesForDisplay hides own sending local echo', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: 'tx-sending',
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 100000,
      status: EventStatus.sending,
      transactionId: 'tx-sending',
    );

    final out = timelineMessagesForDisplay([localEcho]);

    expect(out, isEmpty);
  });

  test('timelineMessagesForDisplay hides own error local echo', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: 'tx-error',
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 100000,
      status: EventStatus.error,
      transactionId: 'tx-error',
    );

    final out = timelineMessagesForDisplay([localEcho]);

    expect(out, isEmpty);
  });

  test('timelineMessagesForDisplay keeps other user non-synced event', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final remoteEvent = _messageEvent(
      room: room,
      eventId: 'remote-error',
      senderId: '@bot:example.org',
      body: '请告诉我您需要什么帮助',
      originServerTsMs: 100000,
      status: EventStatus.error,
      transactionId: 'remote-error',
    );

    final out = timelineMessagesForDisplay([remoteEvent]);

    expect(out, [remoteEvent]);
  });
```

- [ ] **Step 2: Run the focused test to verify RED**

Run:

```bash
flutter test test/matrix/timeline_messages_test.dart
```

Expected: FAIL. The two new current-user `sending` / `error` tests should fail because `_isOwnSentLocalEcho` only filters `EventStatus.sent`.

---

### Task 2: Filter Current-User Non-Synced Local Echoes

**Files:**
- Modify: `lib/matrix/timeline_messages.dart`

- [ ] **Step 1: Replace the initial local echo filter**

Change this:

```dart
  final list = events.where((e) => !_isOwnSentLocalEcho(e)).toList();
```

To this:

```dart
  final list = events.where((e) => !_isOwnUnSyncedLocalEcho(e)).toList();
```

- [ ] **Step 2: Replace `_isOwnSentLocalEcho`**

Change this:

```dart
bool _isOwnSentLocalEcho(Event event) {
  final transactionId = event.transactionId;
  final ownUserId = event.room.client.userID;
  return event.status == EventStatus.sent &&
      transactionId != null &&
      transactionId.isNotEmpty &&
      ownUserId != null &&
      ownUserId.isNotEmpty &&
      event.senderId == ownUserId;
}
```

To this:

```dart
bool _isOwnUnSyncedLocalEcho(Event event) {
  final ownUserId = event.room.client.userID;
  return !event.status.isSynced &&
      ownUserId != null &&
      ownUserId.isNotEmpty &&
      event.senderId == ownUserId;
}
```

Rationale: Matrix SDK local echoes can be `sending`, `sent`, or `error`. All are local-only display artifacts when `senderId` is the current user and `status` is not synced. Server-confirmed messages are `EventStatus.synced` and remain visible.

- [ ] **Step 3: Run the focused test to verify GREEN**

Run:

```bash
flutter test test/matrix/timeline_messages_test.dart
```

Expected: PASS.

---

### Task 3: Run Regression Verification

**Files:**
- Verify only.

- [ ] **Step 1: Run analyzer on touched files**

Run:

```bash
dart analyze lib/matrix/timeline_messages.dart test/matrix/timeline_messages_test.dart
```

Expected: `No issues found!`

- [ ] **Step 2: Run full Flutter test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Manual Android verification**

Install/run the app and open a room that previously showed two stale messages at the bottom.

Expected:

- The stale bottom messages are gone.
- Newly sent messages still appear after server sync.
- Repeated real synced messages with the same body still appear if they were actually sent multiple times.
- Different rooms no longer show their room-specific stale bottom messages.

---

### Task 4: Commit

**Files:**
- Modify: `lib/matrix/timeline_messages.dart`
- Modify: `test/matrix/timeline_messages_test.dart`

- [ ] **Step 1: Review diff**

Run:

```bash
git diff -- lib/matrix/timeline_messages.dart test/matrix/timeline_messages_test.dart
```

Expected: only the local echo filter and tests changed.

- [ ] **Step 2: Commit**

Run:

```bash
git add lib/matrix/timeline_messages.dart test/matrix/timeline_messages_test.dart
git commit -m "fix(chat): hide stale local echo messages"
```

Expected: commit succeeds.

---

## Self-Review

- Spec coverage: The plan addresses the screenshot symptom by filtering Matrix SDK local echo statuses before UI rendering.
- Placeholder scan: No placeholders remain.
- Type consistency: Uses existing `EventStatus`, `status.isSynced`, `event.room.client.userID`, and `timelineMessagesForDisplay` APIs.
- Scope check: The plan avoids layout changes and database mutation; it is a narrow display-filter fix.
