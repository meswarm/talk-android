# FCM Push Notification MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add app-side Firebase Cloud Messaging so Android can show Talk system notifications after the Flutter process has been reclaimed.

**Architecture:** Firebase Messaging owns remote push delivery and token lifecycle. `NotificationService` remains the local notification presenter and tap callback bridge. A new `push/` module isolates Firebase-specific code behind testable interfaces.

**Tech Stack:** Flutter, Dart, `firebase_core`, `firebase_messaging`, `flutter_local_notifications`, Android Gradle Google Services plugin, Firebase Console/HTTP v1 for manual push tests.

---

## File Structure

- Modify `pubspec.yaml`: add Firebase dependencies.
- Modify `android/settings.gradle.kts`: register Google Services Gradle plugin.
- Modify `android/app/build.gradle.kts`: apply Google Services plugin.
- Modify `android/app/src/main/AndroidManifest.xml`: add Android 13 notification permission and default FCM notification channel metadata.
- Create `lib/push/fcm_push_payload.dart`: parse Firebase message fields into app-level notification payload.
- Create `lib/push/fcm_messaging_client.dart`: interface plus Firebase implementation used by `FcmPushService`.
- Create `lib/push/fcm_push_service.dart`: initialize Firebase Messaging, expose token/status, listen to foreground messages and notification-open events.
- Modify `lib/services/notification_service.dart`: expose a public method for push notifications and keep tap routing centralized.
- Create `lib/pages/push_notification_settings_page.dart`: profile page for token/status/manual local test.
- Modify `lib/pages/profile_page.dart`: link to push settings.
- Modify `lib/main.dart`: bootstrap FCM after local notifications are initialized.
- Test `test/push/fcm_push_payload_test.dart`.
- Test `test/push/fcm_push_service_test.dart`.
- Test `test/pages/push_notification_settings_page_test.dart`.

---

### Task 1: Firebase Dependencies And Android Wiring

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add Flutter dependencies**

Run:

```bash
flutter pub add firebase_core firebase_messaging
```

Expected: `pubspec.yaml` and `pubspec.lock` include `firebase_core` and `firebase_messaging`.

- [ ] **Step 2: Register Google Services plugin**

In `android/settings.gradle.kts`, update the `plugins` block to include:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}
```

- [ ] **Step 3: Apply Google Services plugin to Android app**

In `android/app/build.gradle.kts`, update the `plugins` block to include:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
```

- [ ] **Step 4: Add Android notification permission and FCM channel metadata**

In `android/app/src/main/AndroidManifest.xml`, add the permission next to existing permissions:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Inside `<application>`, add this metadata before the Flutter embedding metadata:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="talk_messages" />
```

- [ ] **Step 5: Add Firebase app config**

Add the Firebase Android config file for package `com.example.talk`:

```text
android/app/google-services.json
```

Use Firebase Console > Project settings > Your apps > Android app. Keep this file in the private repository. If the repository is made public later, review whether the Firebase project identifiers should remain committed.

- [ ] **Step 6: Verify dependency wiring**

Run:

```bash
flutter pub get
flutter build apk --debug
```

Expected: dependency resolution succeeds and Android debug build reaches `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock android/settings.gradle.kts android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/google-services.json
git commit -m "feat: add Firebase Messaging Android wiring"
```

---

### Task 2: Push Payload Parser

**Files:**
- Create: `lib/push/fcm_push_payload.dart`
- Create: `test/push/fcm_push_payload_test.dart`

- [ ] **Step 1: Write failing parser tests**

Create `test/push/fcm_push_payload_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/push/fcm_push_payload.dart';

void main() {
  test('parses notification and data fields', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: '日程todo',
      notificationBody: 'T: 当前有新任务',
      data: {
        'roomId': '!room:hs',
        'eventId': r'$event',
        'senderName': 'T',
      },
    );

    expect(payload.roomId, '!room:hs');
    expect(payload.eventId, r'$event');
    expect(payload.senderName, 'T');
    expect(payload.title, '日程todo');
    expect(payload.body, 'T: 当前有新任务');
    expect(payload.hasRoomTarget, isTrue);
  });

  test('falls back to generic title and body', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: null,
      notificationBody: null,
      data: const {},
    );

    expect(payload.title, 'Talk');
    expect(payload.body, '你有一条新消息');
    expect(payload.hasRoomTarget, isFalse);
  });

  test('trims empty fields', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: '   ',
      notificationBody: '',
      data: const {'roomId': '   ', 'senderName': '  Alice  '},
    );

    expect(payload.title, 'Talk');
    expect(payload.body, '你有一条新消息');
    expect(payload.roomId, isNull);
    expect(payload.senderName, 'Alice');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/push/fcm_push_payload_test.dart
```

Expected: FAIL because `lib/push/fcm_push_payload.dart` does not exist.

- [ ] **Step 3: Implement payload parser**

Create `lib/push/fcm_push_payload.dart`:

```dart
class FcmPushPayload {
  const FcmPushPayload({
    required this.title,
    required this.body,
    required this.roomId,
    required this.eventId,
    required this.senderName,
  });

  final String title;
  final String body;
  final String? roomId;
  final String? eventId;
  final String? senderName;

  bool get hasRoomTarget => roomId != null && roomId!.isNotEmpty;

  factory FcmPushPayload.fromParts({
    required String? notificationTitle,
    required String? notificationBody,
    required Map<String, dynamic> data,
  }) {
    String? clean(Object? raw) {
      final value = raw?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return FcmPushPayload(
      title: clean(notificationTitle) ?? 'Talk',
      body: clean(notificationBody) ?? '你有一条新消息',
      roomId: clean(data['roomId']),
      eventId: clean(data['eventId']),
      senderName: clean(data['senderName']),
    );
  }

  String? get notificationPayload => hasRoomTarget ? roomId : null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
flutter test test/push/fcm_push_payload_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/push/fcm_push_payload.dart test/push/fcm_push_payload_test.dart
git commit -m "feat: parse FCM push payloads"
```

---

### Task 3: FCM Messaging Service

**Files:**
- Create: `lib/push/fcm_messaging_client.dart`
- Create: `lib/push/fcm_push_service.dart`
- Create: `test/push/fcm_push_service_test.dart`

- [ ] **Step 1: Write failing service tests**

Create `test/push/fcm_push_service_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talk/push/fcm_messaging_client.dart';
import 'package:talk/push/fcm_push_payload.dart';
import 'package:talk/push/fcm_push_service.dart';

void main() {
  test('bootstrap requests permission and loads token', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final service = FcmPushService(client: client);

    await service.bootstrap();

    expect(client.permissionRequested, isTrue);
    expect(service.token, 'token-1');
    expect(service.available, isTrue);
    expect(service.error, isNull);
  });

  test('foreground messages are presented as local notifications', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final shown = <FcmPushPayload>[];
    final service = FcmPushService(
      client: client,
      showLocalNotification: shown.add,
    );
    await service.bootstrap();

    client.emitForeground(
      const FcmRemoteMessageData(
        title: 'Room',
        body: 'Alice: hi',
        data: {'roomId': '!r:hs'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(shown.single.roomId, '!r:hs');
    expect(shown.single.title, 'Room');
  });

  test('opened messages notify room callback', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final openedRooms = <String>[];
    final service = FcmPushService(
      client: client,
      onOpenRoom: openedRooms.add,
    );
    await service.bootstrap();

    client.emitOpened(
      const FcmRemoteMessageData(
        title: 'Room',
        body: 'Alice: hi',
        data: {'roomId': '!r:hs'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(openedRooms, ['!r:hs']);
  });
}

class FakeFcmMessagingClient implements FcmMessagingClient {
  FakeFcmMessagingClient({this.token});

  final String? token;
  bool permissionRequested = false;
  final foregroundController = StreamController<FcmRemoteMessageData>.broadcast();
  final openedController = StreamController<FcmRemoteMessageData>.broadcast();

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp => openedController.stream;

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
  }

  void emitForeground(FcmRemoteMessageData message) {
    foregroundController.add(message);
  }

  void emitOpened(FcmRemoteMessageData message) {
    openedController.add(message);
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/push/fcm_push_service_test.dart
```

Expected: FAIL because push service files do not exist.

- [ ] **Step 3: Implement messaging client abstraction**

Create `lib/push/fcm_messaging_client.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmRemoteMessageData {
  const FcmRemoteMessageData({
    required this.title,
    required this.body,
    required this.data,
  });

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  factory FcmRemoteMessageData.fromRemoteMessage(RemoteMessage message) {
    return FcmRemoteMessageData(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
    );
  }
}

abstract class FcmMessagingClient {
  Future<void> requestPermission();
  Future<String?> getToken();
  Future<FcmRemoteMessageData?> getInitialMessage();
  Stream<FcmRemoteMessageData> get onForegroundMessage;
  Stream<FcmRemoteMessageData> get onMessageOpenedApp;
}

class FirebaseFcmMessagingClient implements FcmMessagingClient {
  FirebaseFcmMessagingClient({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : FcmRemoteMessageData.fromRemoteMessage(message);
  }

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(FcmRemoteMessageData.fromRemoteMessage);

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(
        FcmRemoteMessageData.fromRemoteMessage,
      );
}
```

- [ ] **Step 4: Implement push service**

Create `lib/push/fcm_push_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fcm_messaging_client.dart';
import 'fcm_push_payload.dart';

typedef ShowFcmLocalNotification = void Function(FcmPushPayload payload);
typedef OpenFcmRoom = void Function(String roomId);

class FcmPushService extends ChangeNotifier {
  FcmPushService({
    FcmMessagingClient? client,
    ShowFcmLocalNotification? showLocalNotification,
    OpenFcmRoom? onOpenRoom,
  }) : _client = client ?? FirebaseFcmMessagingClient(),
       _showLocalNotification = showLocalNotification,
       _onOpenRoom = onOpenRoom;

  final FcmMessagingClient _client;
  final ShowFcmLocalNotification? _showLocalNotification;
  final OpenFcmRoom? _onOpenRoom;

  StreamSubscription<FcmRemoteMessageData>? _foregroundSub;
  StreamSubscription<FcmRemoteMessageData>? _openedSub;

  String? _token;
  String? _error;
  bool _bootstrapped = false;

  String? get token => _token;
  String? get error => _error;
  bool get available => _token != null && _token!.isNotEmpty;
  bool get bootstrapped => _bootstrapped;

  Future<void> bootstrap() async {
    try {
      await _client.requestPermission();
      _token = await _client.getToken();
      _error = null;
      _bootstrapped = true;
      _foregroundSub?.cancel();
      _openedSub?.cancel();
      _foregroundSub = _client.onForegroundMessage.listen(_handleForeground);
      _openedSub = _client.onMessageOpenedApp.listen(_handleOpened);
      final initial = await _client.getInitialMessage();
      if (initial != null) _handleOpened(initial);
    } catch (e) {
      _error = '$e';
      _bootstrapped = true;
    }
    notifyListeners();
  }

  Future<void> refreshToken() async {
    try {
      _token = await _client.getToken();
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    notifyListeners();
  }

  void _handleForeground(FcmRemoteMessageData message) {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: message.title,
      notificationBody: message.body,
      data: message.data,
    );
    _showLocalNotification?.call(payload);
  }

  void _handleOpened(FcmRemoteMessageData message) {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: message.title,
      notificationBody: message.body,
      data: message.data,
    );
    final roomId = payload.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      _onOpenRoom?.call(roomId);
    }
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 5: Run service tests**

Run:

```bash
flutter test test/push/fcm_push_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/push/fcm_messaging_client.dart lib/push/fcm_push_service.dart test/push/fcm_push_service_test.dart
git commit -m "feat: add FCM push service"
```

---

### Task 4: Local Notification Bridge For FCM

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Expose public push notification method**

In `lib/services/notification_service.dart`, add this public method near `_showNotification`:

```dart
Future<void> showPushNotification({
  required String title,
  required String body,
  String? roomId,
}) {
  return _showNotification(
    roomId: roomId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}',
    title: title,
    body: body,
  );
}
```

- [ ] **Step 2: Keep existing Matrix notification behavior unchanged**

Do not change `startListening(Client client)` except to call the same `_showNotification` method it already uses.

- [ ] **Step 3: Run notification-related tests**

Run:

```bash
flutter test test/media_transport_policy_test.dart test/pages/voice_announcement_settings_page_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: expose local notification bridge for push"
```

---

### Task 5: Bootstrap FCM In App Startup

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Import Firebase and push service**

Add imports:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'push/fcm_push_payload.dart';
import 'push/fcm_push_service.dart';
```

- [ ] **Step 2: Initialize Firebase before runApp**

In `main()`, after `WidgetsFlutterBinding.ensureInitialized();`, add:

```dart
try {
  await Firebase.initializeApp();
} catch (_) {
  // The push settings page will show the unavailable state.
}
```

- [ ] **Step 3: Add service field**

In `_TalkAppState`, add:

```dart
late final FcmPushService _fcmPushService;
```

- [ ] **Step 4: Construct and bootstrap push service**

In `initState()`, after notification callbacks are assigned, add:

```dart
_fcmPushService = FcmPushService(
  showLocalNotification: _showFcmLocalNotification,
  onOpenRoom: _onNotificationTap,
);
unawaited(_fcmPushService.bootstrap());
```

Add method:

```dart
void _showFcmLocalNotification(FcmPushPayload payload) {
  unawaited(
    _notificationService.showPushNotification(
      title: payload.title,
      body: payload.body,
      roomId: payload.roomId,
    ),
  );
}
```

- [ ] **Step 5: Provide and dispose service**

In `dispose()`:

```dart
_fcmPushService.dispose();
```

In `MultiProvider.providers`:

```dart
ChangeNotifierProvider.value(value: _fcmPushService),
```

- [ ] **Step 6: Run smoke build checks**

Run:

```bash
flutter analyze
flutter build apk --debug
```

Expected: analyze has no issues and debug APK builds.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart
git commit -m "feat: bootstrap FCM push notifications"
```

---

### Task 6: Push Notification Settings Page

**Files:**
- Create: `lib/pages/push_notification_settings_page.dart`
- Modify: `lib/pages/profile_page.dart`
- Create: `test/pages/push_notification_settings_page_test.dart`

- [ ] **Step 1: Write failing widget test**

Create `test/pages/push_notification_settings_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talk/pages/push_notification_settings_page.dart';
import 'package:talk/push/fcm_messaging_client.dart';
import 'package:talk/push/fcm_push_service.dart';

void main() {
  testWidgets('shows token and refresh action', (tester) async {
    final service = FcmPushService(client: _TokenClient('token-abc'));
    await service.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<FcmPushService>.value(
        value: service,
        child: const MaterialApp(home: PushNotificationSettingsPage()),
      ),
    );

    expect(find.text('FCM 推送通知'), findsOneWidget);
    expect(find.text('token-abc'), findsOneWidget);
    expect(find.text('刷新 Token'), findsOneWidget);
  });
}

class _TokenClient implements FcmMessagingClient {
  _TokenClient(this.token);

  final String token;

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage => const Stream.empty();

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> requestPermission() async {}
}
```

The test intentionally fails until the page exists.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/pages/push_notification_settings_page_test.dart
```

Expected: FAIL because page does not exist.

- [ ] **Step 3: Implement settings page**

Create `lib/pages/push_notification_settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../push/fcm_push_service.dart';
import '../theme/app_colors.dart';

class PushNotificationSettingsPage extends StatelessWidget {
  const PushNotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FcmPushService>();
    final token = service.token;

    return Scaffold(
      appBar: AppBar(title: const Text('FCM 推送通知')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '用于在 App 被系统回收后仍接收系统通知。当前 MVP 先显示本机 FCM Token，后续服务端会用它推送新消息。',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
          Text(
            service.available ? '状态：已获取 Token' : '状态：未获取 Token',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (service.error != null) ...[
            const SizedBox(height: 12),
            Text(service.error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          SelectableText(token ?? '暂无 Token'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => service.refreshToken(),
            child: const Text('刷新 Token'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: token == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: token));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token 已复制'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
            child: const Text('复制 Token'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Link from profile page**

In `lib/pages/profile_page.dart`, import:

```dart
import 'push_notification_settings_page.dart';
```

Add method:

```dart
void _openPushNotificationSettings() {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PushNotificationSettingsPage()),
  );
}
```

Add a profile item near "语音播报":

```dart
_buildProfileItem(
  isDark: isDark,
  icon: Icons.notifications_active_outlined,
  label: 'FCM 推送通知',
  value: '系统回收后接收通知',
  onTap: _saving ? null : _openPushNotificationSettings,
),
_buildDivider(isDark),
```

- [ ] **Step 5: Run widget test**

Run:

```bash
flutter test test/pages/push_notification_settings_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/push_notification_settings_page.dart lib/pages/profile_page.dart test/pages/push_notification_settings_page_test.dart
git commit -m "feat: add FCM push settings page"
```

---

### Task 7: End-To-End Verification

**Files:**
- No source files unless verification finds a bug.

- [ ] **Step 1: Run full automated checks**

Run:

```bash
flutter test
flutter analyze
flutter build apk --debug
```

Expected:

- `flutter test`: all tests pass.
- `flutter analyze`: no issues found.
- `flutter build apk --debug`: APK builds successfully.

- [ ] **Step 2: Install APK on Android device**

Run:

```bash
flutter install
```

Expected: app installs on the connected Android device.

- [ ] **Step 3: Copy FCM token**

Open Talk > 个人资料 > FCM 推送通知 > 复制 Token.

Expected: the page shows a non-empty token.

- [ ] **Step 4: Send test notification from Firebase Console**

Use Firebase Console > Cloud Messaging > Send test message. Paste the copied token. Use:

```text
Title: 日程todo
Body: T: 这是一条 FCM 测试消息
Custom data:
roomId = !room:example.com
eventId = $manual-test
senderName = T
```

Expected:

- When app is foregrounded, Talk shows a local system notification.
- When app is backgrounded, Android notification tray shows the notification.
- When app process is killed by the system or removed from recents, Android notification tray still shows the notification.

Do not use Android Settings > Force stop for this acceptance test. Force-stop blocks app delivery until the user manually opens the app again.

- [ ] **Step 5: Commit verification notes if needed**

If manual verification reveals device-specific setup notes, add them to a follow-up doc:

```bash
git add docs/superpowers/specs/2026-05-04-fcm-push-notification-mvp-design.md docs/superpowers/plans/2026-05-04-fcm-push-notification-mvp.md
git commit -m "docs: add FCM push notification MVP plan"
```
