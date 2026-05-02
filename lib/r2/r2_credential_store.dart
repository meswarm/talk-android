import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'r2_models.dart';

/// Plain JSON in secure storage (OS-protected). No user passphrase.
const _secureKeyPlain = 'talk_r2_plain_v1_json';

/// Legacy PBKDF2-wrapped blob (removed; cannot migrate without passphrase).
const _secureKeyWrapped = 'talk_r2_wrapped_v1_json';

const _prefPostpone = 'talk_r2_unlock_postponed';

final _storage = FlutterSecureStorage();

class R2CredentialStore {
  static Future<R2SecretPayload?> loadPayload() async {
    final s = await _storage.read(key: _secureKeyPlain);
    if (s == null || s.isEmpty) return null;
    try {
      return R2SecretPayload.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePayload(R2SecretPayload payload) {
    return _storage.write(
      key: _secureKeyPlain,
      value: jsonEncode(payload.toJson()),
    );
  }

  static Future<void> clearPayload() async {
    await _storage.delete(key: _secureKeyPlain);
  }

  /// If only legacy wrapped credentials exist, drop them (cannot decrypt).
  static Future<void> migrateLegacyWrappedIfNeeded() async {
    final plain = await _storage.read(key: _secureKeyPlain);
    if (plain != null && plain.isNotEmpty) return;
    final wrapped = await _storage.read(key: _secureKeyWrapped);
    if (wrapped == null || wrapped.isEmpty) return;
    await _storage.delete(key: _secureKeyWrapped);
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefPostpone);
  }

  static Future<void> clearLegacyWrapped() async {
    await _storage.delete(key: _secureKeyWrapped);
  }

  static Future<void> clearPostponePref() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefPostpone);
  }
}
