# Android Keep-Alive Voice Announcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-controlled Android foreground service that keeps Talk's existing new-message notification and voice announcement path more reliable while the app is in the background.

**Architecture:** Add a small Android `Service` that owns the foreground notification, a Flutter `MethodChannel` bridge for start/stop/status/settings, and a `KeepAliveController` that persists the user's switch and coordinates service lifecycle. The existing `VoiceAnnouncementSettingsPage` becomes the UI entry point; Matrix listening and Doubao TTS remain unchanged.

**Tech Stack:** Flutter, Provider, SharedPreferences via existing `LocalStorage`, Android Kotlin, Android foreground service APIs, MethodChannel, flutter_test.

---

## File Structure

- Create `lib/keep_alive/keep_alive_service_bridge.dart`
  - Defines the platform boundary and a default MethodChannel implementation.
  - Returns no-op behavior on non-Android platforms through `MissingPluginException` handling.
- Create `lib/keep_alive/keep_alive_controller.dart`
  - Owns UI state: enabled, running, busy, error.
  - Reads/writes `LocalStorage`.
  - Calls the bridge to start/stop/open battery settings.
- Create `test/keep_alive/keep_alive_controller_test.dart`
  - Tests storage roundtrip, start/stop behavior, and failure rollback.
- Modify `lib/services/local_storage.dart`
  - Adds `talk_voice_keep_alive_enabled`.
- Modify `test/services/local_storage_composer_and_draft_test.dart`
  - Adds preference roundtrip coverage.
- Modify `android/app/src/main/AndroidManifest.xml`
  - Adds foreground-service and notification permissions.
  - Registers the keep-alive service.
- Create `android/app/src/main/kotlin/com/example/talk/TalkKeepAliveService.kt`
  - Implements foreground service and persistent notification.
- Modify `android/app/src/main/kotlin/com/example/talk/MainActivity.kt`
  - Registers MethodChannel handlers.
- Modify `lib/main.dart`
  - Creates/provides `KeepAliveController`.
  - Calls controller bootstrap during app initialization.
- Modify `lib/pages/voice_announcement_settings_page.dart`
  - Adds the "常驻监听模式" settings section.
- Modify `test/pages/voice_announcement_settings_page_test.dart`
  - Provides fake keep-alive controller dependencies and tests UI behavior.

---

### Task 1: Persist the Keep-Alive Switch

**Files:**
- Modify: `lib/services/local_storage.dart`
- Modify: `test/services/local_storage_composer_and_draft_test.dart`

- [ ] **Step 1: Write the failing LocalStorage test**

Add this test near the other boolean preference tests in `test/services/local_storage_composer_and_draft_test.dart`:

```dart
test('voice keep alive defaults off and roundtrips', () async {
  final ls = LocalStorage();
  expect(await ls.loadVoiceKeepAliveEnabled(), false);

  await ls.saveVoiceKeepAliveEnabled(true);
  expect(await ls.loadVoiceKeepAliveEnabled(), true);

  await ls.saveVoiceKeepAliveEnabled(false);
  expect(await ls.loadVoiceKeepAliveEnabled(), false);
});
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
flutter test test/services/local_storage_composer_and_draft_test.dart
```

Expected: FAIL because `loadVoiceKeepAliveEnabled` and `saveVoiceKeepAliveEnabled` do not exist.

- [ ] **Step 3: Add the LocalStorage implementation**

In `lib/services/local_storage.dart`, add this key near the other local-only settings:

```dart
  /// Android foreground-service mode for voice announcement reliability.
  static const _keyVoiceKeepAliveEnabled = 'talk_voice_keep_alive_enabled';
```

Add these methods near the other global preference methods:

```dart
  Future<bool> loadVoiceKeepAliveEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool(_keyVoiceKeepAliveEnabled) ?? false;
  }

  Future<void> saveVoiceKeepAliveEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_keyVoiceKeepAliveEnabled, enabled);
  }
```

- [ ] **Step 4: Run the LocalStorage test**

Run:

```bash
flutter test test/services/local_storage_composer_and_draft_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/local_storage.dart test/services/local_storage_composer_and_draft_test.dart
git commit -m "feat: persist voice keep-alive preference"
```

---

### Task 2: Add Flutter Bridge and Testable Controller

**Files:**
- Create: `lib/keep_alive/keep_alive_service_bridge.dart`
- Create: `lib/keep_alive/keep_alive_controller.dart`
- Create: `test/keep_alive/keep_alive_controller_test.dart`

- [ ] **Step 1: Write the controller tests**

Create `test/keep_alive/keep_alive_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/keep_alive/keep_alive_controller.dart';
import 'package:talk/keep_alive/keep_alive_service_bridge.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  test('bootstrap starts service when saved preference is enabled', () async {
    final storage = LocalStorage();
    await storage.saveVoiceKeepAliveEnabled(true);
    final bridge = _FakeKeepAliveBridge();
    final controller = KeepAliveController(storage: storage, bridge: bridge);

    await controller.bootstrap();

    expect(controller.enabled, true);
    expect(controller.running, true);
    expect(bridge.startCalls, 1);
    expect(controller.error, isNull);
  });

  test('setEnabled true persists and starts the service', () async {
    final storage = LocalStorage();
    final bridge = _FakeKeepAliveBridge();
    final controller = KeepAliveController(storage: storage, bridge: bridge);
    await controller.bootstrap();

    await controller.setEnabled(true);

    expect(await storage.loadVoiceKeepAliveEnabled(), true);
    expect(controller.enabled, true);
    expect(controller.running, true);
    expect(bridge.startCalls, 1);
  });

  test('setEnabled false persists and stops the service', () async {
    final storage = LocalStorage();
    await storage.saveVoiceKeepAliveEnabled(true);
    final bridge = _FakeKeepAliveBridge();
    final controller = KeepAliveController(storage: storage, bridge: bridge);
    await controller.bootstrap();

    await controller.setEnabled(false);

    expect(await storage.loadVoiceKeepAliveEnabled(), false);
    expect(controller.enabled, false);
    expect(controller.running, false);
    expect(bridge.stopCalls, 1);
  });

  test('start failure rolls the switch back off', () async {
    final storage = LocalStorage();
    final bridge = _FakeKeepAliveBridge()..startError = StateError('no permission');
    final controller = KeepAliveController(storage: storage, bridge: bridge);

    await controller.setEnabled(true);

    expect(await storage.loadVoiceKeepAliveEnabled(), false);
    expect(controller.enabled, false);
    expect(controller.running, false);
    expect(controller.error, contains('no permission'));
  });
}

class _FakeKeepAliveBridge implements KeepAliveServiceBridge {
  int startCalls = 0;
  int stopCalls = 0;
  int openSettingsCalls = 0;
  Object? startError;
  bool running = false;

  @override
  Future<void> start() async {
    startCalls += 1;
    final err = startError;
    if (err != null) throw err;
    running = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> openBatteryOptimizationSettings() async {
    openSettingsCalls += 1;
  }
}
```

- [ ] **Step 2: Run the failing controller tests**

Run:

```bash
flutter test test/keep_alive/keep_alive_controller_test.dart
```

Expected: FAIL because the keep-alive files do not exist.

- [ ] **Step 3: Add the MethodChannel bridge**

Create `lib/keep_alive/keep_alive_service_bridge.dart`:

```dart
import 'package:flutter/services.dart';

abstract class KeepAliveServiceBridge {
  Future<void> start();
  Future<void> stop();
  Future<bool> isRunning();
  Future<void> openBatteryOptimizationSettings();
}

class MethodChannelKeepAliveServiceBridge implements KeepAliveServiceBridge {
  MethodChannelKeepAliveServiceBridge({
    MethodChannel channel = const MethodChannel('talk/keep_alive_service'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> start() async {
    await _invokeVoid('startKeepAliveService');
  }

  @override
  Future<void> stop() async {
    await _invokeVoid('stopKeepAliveService');
  }

  @override
  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isKeepAliveServiceRunning') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openBatteryOptimizationSettings() async {
    await _invokeVoid('openBatteryOptimizationSettings');
  }

  Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      return;
    }
  }
}
```

- [ ] **Step 4: Add the controller**

Create `lib/keep_alive/keep_alive_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../services/local_storage.dart';
import 'keep_alive_service_bridge.dart';

class KeepAliveController extends ChangeNotifier {
  KeepAliveController({
    LocalStorage? storage,
    KeepAliveServiceBridge? bridge,
  }) : _storage = storage ?? LocalStorage(),
       _bridge = bridge ?? MethodChannelKeepAliveServiceBridge();

  final LocalStorage _storage;
  final KeepAliveServiceBridge _bridge;

  bool _enabled = false;
  bool _running = false;
  bool _busy = false;
  String? _error;

  bool get enabled => _enabled;
  bool get running => _running;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> bootstrap() async {
    _enabled = await _storage.loadVoiceKeepAliveEnabled();
    _running = await _bridge.isRunning();
    notifyListeners();

    if (_enabled && !_running) {
      await _startFromSavedPreference();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      if (enabled) {
        await _bridge.start();
        await _storage.saveVoiceKeepAliveEnabled(true);
        _enabled = true;
        _running = true;
      } else {
        await _bridge.stop();
        await _storage.saveVoiceKeepAliveEnabled(false);
        _enabled = false;
        _running = false;
      }
    } catch (e) {
      await _storage.saveVoiceKeepAliveEnabled(false);
      _enabled = false;
      _running = await _bridge.isRunning();
      _error = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      _error = null;
      notifyListeners();
      await _bridge.openBatteryOptimizationSettings();
    } catch (e) {
      _error = '$e';
      notifyListeners();
    }
  }

  Future<void> _startFromSavedPreference() async {
    try {
      await _bridge.start();
      _running = true;
      _error = null;
    } catch (e) {
      _running = false;
      _error = '$e';
    } finally {
      notifyListeners();
    }
  }
}
```

- [ ] **Step 5: Run the controller tests**

Run:

```bash
flutter test test/keep_alive/keep_alive_controller_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/keep_alive test/keep_alive
git commit -m "feat: add keep-alive controller and bridge"
```

---

### Task 3: Implement Android Foreground Service

**Files:**
- Create: `android/app/src/main/kotlin/com/example/talk/TalkKeepAliveService.kt`
- Modify: `android/app/src/main/kotlin/com/example/talk/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add manifest permissions and service declaration**

Modify `android/app/src/main/AndroidManifest.xml`.

Add these permissions near the existing permissions:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Add this service inside `<application>`:

```xml
        <service
            android:name=".TalkKeepAliveService"
            android:exported="false" />
```

- [ ] **Step 2: Create the Android foreground service**

Create `android/app/src/main/kotlin/com/example/talk/TalkKeepAliveService.kt`:

```kotlin
package com.example.talk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class TalkKeepAliveService : Service() {
    override fun onCreate() {
        super.onCreate()
        isRunning = true
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Talk 常驻监听",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "保持 Talk 新消息语音播报监听"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Talk 语音播报监听中")
            .setContentText("正在保持新消息语音播报监听")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    companion object {
        const val CHANNEL_ID = "talk_keep_alive"
        const val NOTIFICATION_ID = 3017
        var isRunning: Boolean = false
            private set
    }
}
```

- [ ] **Step 3: Add AndroidX core dependency if needed**

Run:

```bash
rg -n "androidx.core" android/app/build.gradle.kts
```

If there is no result, add this dependency to `android/app/build.gradle.kts`:

```kotlin
    implementation("androidx.core:core-ktx:1.13.1")
```

Keep the existing `coreLibraryDesugaring(...)` line.

- [ ] **Step 4: Register MethodChannel handlers**

Modify `android/app/src/main/kotlin/com/example/talk/MainActivity.kt`.

Add imports:

```kotlin
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
```

Add this method override inside `MainActivity`:

```kotlin
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "talk/keep_alive_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKeepAliveService" -> {
                    startKeepAliveService()
                    result.success(null)
                }
                "stopKeepAliveService" -> {
                    stopService(Intent(this, TalkKeepAliveService::class.java))
                    result.success(null)
                }
                "isKeepAliveServiceRunning" -> {
                    result.success(TalkKeepAliveService.isRunning)
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
```

Add these helper methods inside `MainActivity`:

```kotlin
    private fun startKeepAliveService() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("POST_NOTIFICATIONS permission is not granted")
        }

        val intent = Intent(this, TalkKeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openBatteryOptimizationSettings() {
        val packageUri = Uri.parse("package:$packageName")
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = packageUri
            }
        } else {
            Intent(Settings.ACTION_SETTINGS)
        }
        startActivity(intent)
    }
```

- [ ] **Step 5: Run Android compile check**

Run:

```bash
flutter build apk --debug
```

Expected: build succeeds. If Android reports missing `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, add this permission to `AndroidManifest.xml`:

```xml
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/example/talk/MainActivity.kt android/app/src/main/kotlin/com/example/talk/TalkKeepAliveService.kt android/app/build.gradle.kts
git commit -m "feat: add Android foreground keep-alive service"
```

---

### Task 4: Add Keep-Alive UI to Voice Announcement Settings

**Files:**
- Modify: `lib/pages/voice_announcement_settings_page.dart`
- Modify: `test/pages/voice_announcement_settings_page_test.dart`

- [ ] **Step 1: Update widget test setup**

Modify `test/pages/voice_announcement_settings_page_test.dart` imports:

```dart
import 'package:talk/keep_alive/keep_alive_controller.dart';
import 'package:talk/keep_alive/keep_alive_service_bridge.dart';
import 'package:talk/services/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Add this `setUp` at the start of `main()`:

```dart
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });
```

Add this helper:

```dart
Future<void> _pumpPage(
  WidgetTester tester, {
  required DoubaoTtsService tts,
  required KeepAliveController keepAlive,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DoubaoTtsService>.value(value: tts),
        ChangeNotifierProvider<KeepAliveController>.value(value: keepAlive),
      ],
      child: const MaterialApp(home: VoiceAnnouncementSettingsPage()),
    ),
  );
}
```

Replace existing direct `ChangeNotifierProvider<DoubaoTtsService>` setup with `_pumpPage(...)`.

Add this fake bridge:

```dart
class _FakeKeepAliveBridge implements KeepAliveServiceBridge {
  int startCalls = 0;
  int stopCalls = 0;
  int openSettingsCalls = 0;
  Object? startError;
  bool running = false;

  @override
  Future<void> start() async {
    startCalls += 1;
    final err = startError;
    if (err != null) throw err;
    running = true;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> openBatteryOptimizationSettings() async {
    openSettingsCalls += 1;
  }
}
```

- [ ] **Step 2: Add failing UI tests**

Add tests:

```dart
testWidgets('shows keep-alive settings and starts service from switch', (
  tester,
) async {
  final ttsStore = _MemoryStore();
  final tts = DoubaoTtsService(
    store: ttsStore,
    httpClient: _FakeClient(),
    customAudioPlayer: (_) async {},
  );
  await tts.bootstrap();
  final bridge = _FakeKeepAliveBridge();
  final keepAlive = KeepAliveController(bridge: bridge);
  await keepAlive.bootstrap();

  await _pumpPage(tester, tts: tts, keepAlive: keepAlive);
  await tester.pumpAndSettle();

  expect(find.text('常驻监听模式'), findsOneWidget);
  expect(find.text('未开启常驻监听'), findsOneWidget);

  await tester.tap(find.text('启用常驻监听模式'));
  await tester.pumpAndSettle();

  expect(bridge.startCalls, 1);
  expect(find.text('常驻监听中'), findsOneWidget);
  expect(find.text('语音播报未配置，常驻服务只会保持监听，不会播放语音。'), findsOneWidget);
});

testWidgets('keep-alive start failure shows error and rolls switch back', (
  tester,
) async {
  final tts = DoubaoTtsService(
    store: _MemoryStore(),
    httpClient: _FakeClient(),
    customAudioPlayer: (_) async {},
  );
  await tts.bootstrap();
  final bridge = _FakeKeepAliveBridge()..startError = StateError('no permission');
  final keepAlive = KeepAliveController(bridge: bridge);
  await keepAlive.bootstrap();

  await _pumpPage(tester, tts: tts, keepAlive: keepAlive);
  await tester.pumpAndSettle();

  await tester.tap(find.text('启用常驻监听模式'));
  await tester.pumpAndSettle();

  expect(find.text('未开启常驻监听'), findsOneWidget);
  expect(find.textContaining('no permission'), findsOneWidget);
});
```

- [ ] **Step 3: Run the failing UI tests**

Run:

```bash
flutter test test/pages/voice_announcement_settings_page_test.dart
```

Expected: FAIL because the page has no keep-alive section.

- [ ] **Step 4: Inject keep-alive controller into the settings page**

Modify imports in `lib/pages/voice_announcement_settings_page.dart`:

```dart
import '../keep_alive/keep_alive_controller.dart';
```

In `build`, add:

```dart
    final keepAlive = context.watch<KeepAliveController>();
    final tts = context.watch<DoubaoTtsService>();
    final ttsConfigured = tts.config?.isConfigured == true;
```

Place this section after the existing `SwitchListTile` for `启用新消息语音播报`:

```dart
          const Divider(height: 28),
          const Text(
            '常驻监听模式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '开启后 Talk 会显示常驻通知，用于提高后台新消息语音播报的可靠性。',
            style: TextStyle(fontSize: 13, color: sub),
          ),
          SwitchListTile(
            value: keepAlive.enabled,
            onChanged: keepAlive.busy
                ? null
                : (v) {
                    unawaited(keepAlive.setEnabled(v));
                  },
            title: const Text('启用常驻监听模式'),
            subtitle: Text(
              keepAlive.running ? '常驻监听中' : '未开启常驻监听',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (keepAlive.enabled && !ttsConfigured) ...[
            const SizedBox(height: 4),
            Text(
              '语音播报未配置，常驻服务只会保持监听，不会播放语音。',
              style: TextStyle(fontSize: 13, color: sub),
            ),
          ],
          if (keepAlive.error != null) ...[
            const SizedBox(height: 8),
            Text(
              keepAlive.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: keepAlive.busy
                  ? null
                  : () {
                      unawaited(keepAlive.openBatteryOptimizationSettings());
                    },
              child: const Text('电池优化设置'),
            ),
          ),
          const Divider(height: 28),
```

Keep the existing TTS configuration form below this section.

- [ ] **Step 5: Run the UI tests**

Run:

```bash
flutter test test/pages/voice_announcement_settings_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/voice_announcement_settings_page.dart test/pages/voice_announcement_settings_page_test.dart
git commit -m "feat: add voice keep-alive settings UI"
```

---

### Task 5: Bootstrap Keep-Alive in the App

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add app bootstrap wiring**

Modify imports in `lib/main.dart`:

```dart
import 'keep_alive/keep_alive_controller.dart';
```

Add a field in `_TalkAppState`:

```dart
  final _keepAliveController = KeepAliveController();
```

In `initState`, after the other bootstrap calls:

```dart
    unawaited(_keepAliveController.bootstrap());
```

In `dispose`, before disposing other services:

```dart
    _keepAliveController.dispose();
```

In `MultiProvider.providers`, add:

```dart
        ChangeNotifierProvider.value(value: _keepAliveController),
```

Place it near the other service providers.

- [ ] **Step 2: Run focused tests**

Run:

```bash
flutter test test/keep_alive/keep_alive_controller_test.dart test/pages/voice_announcement_settings_page_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run full verification**

Run:

```bash
flutter test
flutter analyze
flutter build apk --debug
```

Expected:

- `flutter test`: all tests pass.
- `flutter analyze`: no issues.
- `flutter build apk --debug`: APK builds successfully.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: bootstrap voice keep-alive service"
```

---

### Task 6: Android Device Manual Verification

**Files:**
- No required source changes.

- [ ] **Step 1: Install debug build**

Run:

```bash
flutter run
```

Expected: App launches on the connected Android device.

- [ ] **Step 2: Verify service start**

Manual steps:

1. Open `个人资料`.
2. Open `语音播报`.
3. Turn on `启用常驻监听模式`.
4. Accept notification permission if Android asks.

Expected:

- A persistent notification appears with title `Talk 语音播报监听中`.
- The settings page shows `常驻监听中`.

- [ ] **Step 3: Verify background behavior**

Manual steps:

1. Press Home.
2. Pull down notification shade.
3. Confirm the Talk persistent notification is still present.
4. Tap the persistent notification.

Expected:

- Notification remains visible while app is backgrounded.
- Tapping notification returns to Talk.

- [ ] **Step 4: Verify service stop**

Manual steps:

1. Return to `语音播报`.
2. Turn off `启用常驻监听模式`.
3. Pull down notification shade.

Expected:

- Persistent notification disappears.
- Settings page shows `未开启常驻监听`.

- [ ] **Step 5: Verify app restart recovery**

Manual steps:

1. Turn `启用常驻监听模式` on again.
2. Close Talk from recent apps without force-stopping it.
3. Open Talk again.
4. Open `语音播报`.

Expected:

- The page shows `常驻监听中`.
- The persistent notification is present after app initialization.

- [ ] **Step 6: Push to GitHub after verification**

Run:

```bash
git status --short
git push
```

Expected:

- `git status --short` has no source changes.
- `git push` updates `origin/main`.

