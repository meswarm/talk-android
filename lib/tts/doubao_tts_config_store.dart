import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'doubao_tts_models.dart';

abstract class DoubaoTtsConfigStore {
  Future<DoubaoTtsConfig?> load();
  Future<void> save(DoubaoTtsConfig config);
  Future<void> clear();
}

const _secureKeyDoubaoTtsConfig = 'talk_doubao_tts_config_v1_json';

class SecureDoubaoTtsConfigStore implements DoubaoTtsConfigStore {
  SecureDoubaoTtsConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<DoubaoTtsConfig?> load() async {
    final raw = await _storage.read(key: _secureKeyDoubaoTtsConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DoubaoTtsConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(DoubaoTtsConfig config) {
    return _storage.write(
      key: _secureKeyDoubaoTtsConfig,
      value: jsonEncode(config.toJson()),
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _secureKeyDoubaoTtsConfig);
  }
}
