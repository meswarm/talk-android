import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'deepseek_config.dart';

abstract class DeepSeekConfigStore {
  Future<DeepSeekConfig?> load();
  Future<void> save(DeepSeekConfig config);
  Future<void> clear();
}

const _secureKeyDeepSeekConfig = 'talk_deepseek_config_v1_json';

class SecureDeepSeekConfigStore implements DeepSeekConfigStore {
  SecureDeepSeekConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<DeepSeekConfig?> load() async {
    final raw = await _storage.read(key: _secureKeyDeepSeekConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeepSeekConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(DeepSeekConfig config) {
    return _storage.write(
      key: _secureKeyDeepSeekConfig,
      value: jsonEncode(config.normalized().toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _secureKeyDeepSeekConfig);
  }
}
