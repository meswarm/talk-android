import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'r2_ref.dart';

class R2CachedBlob {
  final String refNorm;
  final String mime;
  final int size;
  final int savedAt;
  final Uint8List data;

  const R2CachedBlob({
    required this.refNorm,
    required this.mime,
    required this.size,
    required this.savedAt,
    required this.data,
  });
}

/// Local media cache keyed by SHA-256 of normalized `r2://` ref (parity with talkweb cache).
///
/// 二进制放在应用目录文件内，SQLite 只存元数据与相对路径，避免 Android
/// `CursorWindow` 单行约 2MB 上限导致 `Row too big`（大图无法 `SELECT *`）。
class R2CacheStore {
  R2CacheStore._();

  static final R2CacheStore instance = R2CacheStore._();

  Database? _db;

  static const _dbVersion = 2;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'talk_r2_media_cache.db');
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(_createTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 在 BLOB 中存整图，大图会触发 CursorWindow；直接丢弃旧缓存表
          await db.execute('DROP TABLE IF EXISTS r2_cache');
          await db.execute(_createTableSql);
        }
      },
    );
    return _db!;
  }

  static const _createTableSql = '''
CREATE TABLE r2_cache (
  ref_hash TEXT PRIMARY KEY,
  ref_norm TEXT NOT NULL,
  mime TEXT NOT NULL,
  size INTEGER NOT NULL,
  saved_at INTEGER NOT NULL,
  blob_path TEXT NOT NULL
)
''';

  static String hashRefKey(String ref) {
    final norm = ref.trim();
    final digest = sha256.convert(utf8.encode(norm));
    return digest.toString();
  }

  Future<Directory> _blobDir() async {
    final dir = await getApplicationSupportDirectory();
    final d = Directory(p.join(dir.path, 'r2_blobs'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  /// 相对 [getApplicationSupportDirectory] 的路径，例如 `r2_blobs/<hash>`。
  String _relativeBlobPath(String refHash) =>
      p.join('r2_blobs', refHash);

  Future<void> _removeBlobFileIfExists(String relativePath) async {
    final support = await getApplicationSupportDirectory();
    final abs = p.join(support.path, relativePath);
    final f = File(abs);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  /// Returns the absolute file path of a cached blob without reading its bytes
  /// into memory. Useful for video/audio players that accept a file path.
  Future<String?> getCachedFilePath(String ref) async {
    final db = await _open();
    final key = hashRefKey(r2RefWithoutQuery(ref));
    final rows = await db.query(
      'r2_cache',
      columns: ['blob_path'],
      where: 'ref_hash = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final support = await getApplicationSupportDirectory();
    final rel = rows.single['blob_path'] as String;
    final abs = p.join(support.path, rel);
    if (!await File(abs).exists()) {
      await db.delete('r2_cache', where: 'ref_hash = ?', whereArgs: [key]);
      return null;
    }
    return abs;
  }

  Future<R2CachedBlob?> get(String ref) async {
    final db = await _open();
    final key = hashRefKey(r2RefWithoutQuery(ref));
    final rows = await db.query(
      'r2_cache',
      columns: ['ref_norm', 'mime', 'size', 'saved_at', 'blob_path'],
      where: 'ref_hash = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final support = await getApplicationSupportDirectory();
    final rel = r['blob_path'] as String;
    final abs = p.join(support.path, rel);
    final file = File(abs);
    if (!await file.exists()) {
      await db.delete('r2_cache', where: 'ref_hash = ?', whereArgs: [key]);
      return null;
    }
    final data = await file.readAsBytes();
    return R2CachedBlob(
      refNorm: r['ref_norm'] as String,
      mime: r['mime'] as String,
      size: r['size'] as int,
      savedAt: r['saved_at'] as int,
      data: data,
    );
  }

  Future<void> put({
    required String refNorm,
    required String mime,
    required Uint8List data,
  }) async {
    final db = await _open();
    final key = hashRefKey(refNorm);
    final existing = await db.query(
      'r2_cache',
      columns: ['blob_path'],
      where: 'ref_hash = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await _removeBlobFileIfExists(existing.single['blob_path'] as String);
    }

    final blobDir = await _blobDir();
    final absPath = p.join(blobDir.path, key);
    await File(absPath).writeAsBytes(data, flush: true);

    final relative = _relativeBlobPath(key);
    await db.insert(
      'r2_cache',
      {
        'ref_hash': key,
        'ref_norm': refNorm,
        'mime': mime,
        'size': data.length,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'blob_path': relative,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
