import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

import 'r2_models.dart';
import 'r2_ref.dart';

/// R2 S3-compatible object URL path (parity with `talkweb/src/r2/r2Presign.ts`).
Uri r2ObjectUri({
  required String accountId,
  required String bucket,
  required String objectKey,
}) {
  final host = '$accountId.r2.cloudflarestorage.com';
  final encodedBucket = Uri.encodeComponent(bucket);
  final keyPart =
      objectKey.split('/').map(Uri.encodeComponent).join('/');
  return Uri.parse('https://$host/$encodedBucket/$keyPart');
}

Future<Uri> presignR2Url({
  required String method,
  required String accessKeyId,
  required String secretAccessKey,
  required String accountId,
  required String bucket,
  required String objectKey,
  required String region,
  String? contentType,
  required int expiresSec,
}) async {
  final reg = region.trim().isEmpty ? 'auto' : region.trim();
  final uri = r2ObjectUri(
    accountId: accountId,
    bucket: bucket,
    objectKey: objectKey,
  );
  final host = uri.host;
  final exp = expiresSec.clamp(60, 86400);

  final signer = AWSSigV4Signer(
    credentialsProvider: StaticCredentialsProvider(
      AWSCredentials(accessKeyId, secretAccessKey),
    ),
  );
  final scope = AWSCredentialScope(
    region: reg,
    service: AWSService.s3,
  );

  final AWSHttpRequest req;
  if (method.toUpperCase() == 'GET') {
    req = AWSHttpRequest.get(
      uri,
      headers: {AWSHeaders.host: host},
    );
  } else if (method.toUpperCase() == 'PUT') {
    final mime = contentType ?? 'application/octet-stream';
    req = AWSHttpRequest.put(
      uri,
      headers: {
        AWSHeaders.host: host,
        AWSHeaders.contentType: mime,
      },
      body: const [],
    );
  } else {
    throw ArgumentError('Unsupported presign method: $method');
  }

  return signer.presign(
    req,
    credentialScope: scope,
    serviceConfiguration: S3ServiceConfiguration(signPayload: false),
    expiresIn: Duration(seconds: exp),
  );
}

Future<Uri> presignR2GetForRef({
  required R2SecretPayload session,
  required ParsedR2Ref parsed,
  int expiresSec = 600,
}) {
  return presignR2Url(
    method: 'GET',
    accessKeyId: session.accessKeyId,
    secretAccessKey: session.secretAccessKey,
    accountId: session.accountId,
    bucket: parsed.bucket,
    objectKey: parsed.objectKey,
    region: session.region,
    expiresSec: expiresSec,
  );
}
