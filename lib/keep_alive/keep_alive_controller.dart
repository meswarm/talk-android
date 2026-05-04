import 'package:flutter/foundation.dart';

import '../services/local_storage.dart';
import 'keep_alive_service_bridge.dart';

class KeepAliveController extends ChangeNotifier {
  KeepAliveController({LocalStorage? storage, KeepAliveServiceBridge? bridge})
    : _storage = storage ?? LocalStorage(),
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
