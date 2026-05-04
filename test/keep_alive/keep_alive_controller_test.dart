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
    final bridge = _FakeKeepAliveBridge()
      ..startError = StateError('no permission');
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
