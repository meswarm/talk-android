import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'r2_cache_store.dart';
import 'r2_credential_store.dart';
import 'r2_models.dart';
import 'r2_presign.dart';
import 'r2_ref.dart';

const _putExpiresSec = 900;
const _getExpiresSec = 600;

/// R2 credentials, presign, cache, and uploads (parity with `talkweb` R2 stack).
/// Mobile: secrets live in OS secure storage only — no user passphrase.
class R2Service extends ChangeNotifier {
  R2Phase _phase = R2Phase.loading;
  R2SecretPayload? _session;

  R2Phase get phase => _phase;
  R2SecretPayload? get session => _session;

  Future<void> bootstrap() async {
    _phase = R2Phase.loading;
    notifyListeners();
    try {
      await R2CredentialStore.migrateLegacyWrappedIfNeeded();
      final payload = await R2CredentialStore.loadPayload();
      if (payload == null) {
        _phase = R2Phase.noStore;
        _session = null;
      } else {
        _session = payload;
        _phase = R2Phase.unlocked;
      }
    } catch (_) {
      _phase = R2Phase.noStore;
      _session = null;
    }
    notifyListeners();
  }

  Future<void> saveCredentials(R2SecretPayload payload) async {
    await R2CredentialStore.savePayload(payload);
    await R2CredentialStore.clearLegacyWrapped();
    await R2CredentialStore.clearPostponePref();
    _session = payload;
    _phase = R2Phase.unlocked;
    notifyListeners();
  }

  Future<void> forgetCredentials() async {
    await R2CredentialStore.clearPayload();
    await R2CredentialStore.clearLegacyWrapped();
    await R2CredentialStore.clearPostponePref();
    _session = null;
    _phase = R2Phase.noStore;
    notifyListeners();
  }

  Future<Uri> presignedGetUri(String ref) async {
    final s = _session;
    final parsed = parseR2Ref(ref);
    if (s == null || parsed == null) {
      throw StateError('R2 未配置或引用无效');
    }
    return presignR2GetForRef(
      session: s,
      parsed: parsed,
      expiresSec: _getExpiresSec,
    );
  }

  Future<String> presignedGetUrlString(String ref) async {
    return (await presignedGetUri(ref)).toString();
  }

  /// Cache-first fetch (parity with `talkweb/src/hooks/useR2BlobUrl.ts`).
  Future<Uint8List> fetchRefBytes(String ref) async {
    final s = _session;
    final parsed = parseR2Ref(ref);
    if (s == null || parsed == null) {
      throw StateError('R2 未配置或引用无效');
    }
    final cacheKey = r2RefWithoutQuery(ref);
    final hit = await R2CacheStore.instance.get(cacheKey);
    if (hit != null) return hit.data;

    final signed = await presignR2GetForRef(
      session: s,
      parsed: parsed,
      expiresSec: _getExpiresSec,
    );
    final resp = await http.get(signed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('R2 下载失败 (${resp.statusCode})');
    }
    final mime = resp.headers['content-type']?.split(';').first.trim() ??
        'application/octet-stream';
    final bytes = Uint8List.fromList(resp.bodyBytes);
    await R2CacheStore.instance.put(
      refNorm: cacheKey,
      mime: mime,
      data: bytes,
    );
    return bytes;
  }

  /// Cache-first fetch that returns a **local file path** instead of in-memory
  /// bytes. Preferred for video / audio players that accept a [File] or path.
  Future<String> fetchRefFile(String ref) async {
    final s = _session;
    final parsed = parseR2Ref(ref);
    if (s == null || parsed == null) {
      throw StateError('R2 未配置或引用无效');
    }
    final cacheKey = r2RefWithoutQuery(ref);
    final cached = await R2CacheStore.instance.getCachedFilePath(cacheKey);
    if (cached != null) return cached;

    final signed = await presignR2GetForRef(
      session: s,
      parsed: parsed,
      expiresSec: _getExpiresSec,
    );
    final resp = await http.get(signed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('R2 下载失败 (${resp.statusCode})');
    }
    final mime = resp.headers['content-type']?.split(';').first.trim() ??
        'application/octet-stream';
    final bytes = Uint8List.fromList(resp.bodyBytes);
    await R2CacheStore.instance.put(
      refNorm: cacheKey,
      mime: mime,
      data: bytes,
    );
    final path = await R2CacheStore.instance.getCachedFilePath(cacheKey);
    if (path == null) throw StateError('缓存写入后仍无法读取');
    return path;
  }

  /// Upload bytes to default bucket; returns `r2://…` ref (parity with `talkweb/src/r2/r2Upload.ts`).
  ///
  /// 若提供 [roomPrefix]（非空），对象键为 `{prefix}/{imgs|videos|audios|files}/…`；
  /// 否则回退为全局 `attachments/…`（仅兼容旧调用；聊天页应在有房间前缀时传入）。
  Future<String> uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required String mime,
    String? roomPrefix,
  }) async {
    final s = _session;
    if (s == null) throw StateError('R2 未配置');
    final objectKey = roomPrefix != null && roomPrefix.isNotEmpty
        ? buildRoomAttachmentObjectKey(
            roomPrefix: roomPrefix,
            fileName: fileName,
            mime: mime,
          )
        : buildAttachmentObjectKey(fileName);
    final putUri = await presignR2Url(
      method: 'PUT',
      accessKeyId: s.accessKeyId,
      secretAccessKey: s.secretAccessKey,
      accountId: s.accountId,
      bucket: s.defaultBucket,
      objectKey: objectKey,
      region: s.region,
      contentType: mime,
      expiresSec: _putExpiresSec,
    );
    final resp = await http.put(
      putUri,
      headers: {'Content-Type': mime},
      body: bytes,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final t = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
      throw StateError('R2 上传失败 (${resp.statusCode}): $t');
    }
    return buildR2Ref(s.defaultBucket, objectKey);
  }
}
