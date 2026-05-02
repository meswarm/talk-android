import 'dart:convert';

/// Fields stored encrypted together (parity with `talkweb/src/r2/r2Types.ts`).
class R2SecretPayload {
  final String accessKeyId;
  final String secretAccessKey;
  final String accountId;
  final String defaultBucket;
  /// Cloudflare R2 / S3 SigV4 region, typically `auto`.
  final String region;

  const R2SecretPayload({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.accountId,
    required this.defaultBucket,
    required this.region,
  });

  Map<String, dynamic> toJson() => {
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'accountId': accountId,
        'defaultBucket': defaultBucket,
        'region': region,
      };

  factory R2SecretPayload.fromJson(Map<String, dynamic> j) {
    return R2SecretPayload(
      accessKeyId: j['accessKeyId'] as String,
      secretAccessKey: j['secretAccessKey'] as String,
      accountId: j['accountId'] as String,
      defaultBucket: j['defaultBucket'] as String,
      region: j['region'] as String,
    );
  }
}

/// PBKDF2 + AES-GCM envelope (parity with `talkweb/src/r2/cryptoWrap.ts`).
class WrappedCredentialsV1 {
  final int v;
  final String saltB64;
  final String ivB64;
  final String ciphertextB64;
  final int? createdAt;

  const WrappedCredentialsV1({
    required this.v,
    required this.saltB64,
    required this.ivB64,
    required this.ciphertextB64,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'v': v,
        'saltB64': saltB64,
        'ivB64': ivB64,
        'ciphertextB64': ciphertextB64,
        if (createdAt != null) 'createdAt': createdAt,
      };

  factory WrappedCredentialsV1.fromJson(Map<String, dynamic> j) {
    return WrappedCredentialsV1(
      v: j['v'] as int,
      saltB64: j['saltB64'] as String,
      ivB64: j['ivB64'] as String,
      ciphertextB64: j['ciphertextB64'] as String,
      createdAt: j['createdAt'] as int?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory WrappedCredentialsV1.fromJsonString(String s) {
    return WrappedCredentialsV1.fromJson(
      jsonDecode(s) as Map<String, dynamic>,
    );
  }
}

enum R2Phase {
  loading,
  noStore,
  unlocked,
}
