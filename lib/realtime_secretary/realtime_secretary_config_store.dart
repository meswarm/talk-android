import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'realtime_secretary_models.dart';

abstract class RealtimeSecretaryConfigStore {
  Future<RealtimeSecretaryConfig?> load();
  Future<void> save(RealtimeSecretaryConfig config);
  Future<void> clear();
}

const _secureKeyRealtimeSecretaryConfig =
    'talk_realtime_secretary_config_v1_json';

class SecureRealtimeSecretaryConfigStore
    implements RealtimeSecretaryConfigStore {
  SecureRealtimeSecretaryConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<RealtimeSecretaryConfig?> load() async {
    final raw = await _storage.read(key: _secureKeyRealtimeSecretaryConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RealtimeSecretaryConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(RealtimeSecretaryConfig config) {
    return _storage.write(
      key: _secureKeyRealtimeSecretaryConfig,
      value: jsonEncode(config.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _secureKeyRealtimeSecretaryConfig);
  }
}
