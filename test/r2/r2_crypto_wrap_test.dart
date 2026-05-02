import 'package:flutter_test/flutter_test.dart';
import 'package:talk/r2/r2_crypto_wrap.dart';
import 'package:talk/r2/r2_models.dart';

void main() {
  test('wrap and unwrap roundtrip', () async {
    const pass = 'correct-horse-battery-staple';
    const payload = R2SecretPayload(
      accessKeyId: 'a',
      secretAccessKey: 's',
      accountId: 'acct',
      defaultBucket: 'buck',
      region: 'auto',
    );
    final w = await wrapCredentials(pass, payload);
    expect(w.v, 1);
    final out = await unwrapCredentials(pass, w);
    expect(out.accessKeyId, payload.accessKeyId);
    expect(out.defaultBucket, payload.defaultBucket);
  });

  test('unwrap wrong passphrase', () async {
    const payload = R2SecretPayload(
      accessKeyId: 'a',
      secretAccessKey: 's',
      accountId: 'acct',
      defaultBucket: 'buck',
      region: 'auto',
    );
    final w = await wrapCredentials('good', payload);
    expect(
      () => unwrapCredentials('bad', w),
      throwsA(isA<StateError>()),
    );
  });
}
