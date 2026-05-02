import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'r2_models.dart';

/// PBKDF2 iteration count (must match `talkweb/src/r2/cryptoWrap.ts`).
const pbkdf2Iterations = 210000;

const _saltBytes = 16;
const _ivBytes = 12;
const _wrapVersion = 1;

final _pbkdf2 = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: pbkdf2Iterations,
  bits: 256,
);

final _aes = AesGcm.with256bits();

String _b64(List<int> bytes) => base64Encode(bytes);

Uint8List _fromB64(String s) => Uint8List.fromList(base64Decode(s));

Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
  return _pbkdf2.deriveKeyFromPassword(
    password: passphrase,
    nonce: salt,
  );
}

/// WebCrypto `subtle.encrypt` stores ciphertext || tag in one buffer; we mirror that.
Future<WrappedCredentialsV1> wrapCredentials(
  String passphrase,
  R2SecretPayload payload,
) async {
  final salt = Uint8List.fromList(
    List.generate(_saltBytes, (_) => Random.secure().nextInt(256)),
  );
  final iv = Uint8List.fromList(
    List.generate(_ivBytes, (_) => Random.secure().nextInt(256)),
  );
  final key = await _deriveKey(passphrase, salt);
  final plain = utf8.encode(jsonEncode(payload.toJson()));
  final box = await _aes.encrypt(
    plain,
    secretKey: key,
    nonce: iv,
  );
  final combined = Uint8List(box.cipherText.length + box.mac.bytes.length);
  combined.setAll(0, box.cipherText);
  combined.setAll(box.cipherText.length, box.mac.bytes);

  return WrappedCredentialsV1(
    v: _wrapVersion,
    saltB64: _b64(salt),
    ivB64: _b64(iv),
    ciphertextB64: _b64(combined),
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

Future<R2SecretPayload> unwrapCredentials(
  String passphrase,
  WrappedCredentialsV1 wrapped,
) async {
  if (wrapped.v != _wrapVersion) {
    throw StateError('Unsupported wrapped credentials version');
  }
  final salt = _fromB64(wrapped.saltB64);
  final iv = _fromB64(wrapped.ivB64);
  final combined = _fromB64(wrapped.ciphertextB64);
  const tagLen = 16;
  if (combined.length < tagLen) {
    throw StateError('口令错误或凭据已损坏');
  }
  final ct = combined.sublist(0, combined.length - tagLen);
  final tag = combined.sublist(combined.length - tagLen);
  final key = await _deriveKey(passphrase, salt);
  try {
    final clear = await _aes.decrypt(
      SecretBox(ct, nonce: iv, mac: Mac(tag)),
      secretKey: key,
    );
    final obj = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    if (obj['accessKeyId'] is! String ||
        obj['secretAccessKey'] is! String ||
        obj['accountId'] is! String ||
        obj['defaultBucket'] is! String ||
        obj['region'] is! String) {
      throw StateError('Invalid credentials payload');
    }
    return R2SecretPayload.fromJson(obj);
  } catch (_) {
    throw StateError('口令错误或凭据已损坏');
  }
}
