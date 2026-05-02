import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'composer_media_result.dart';

/// 媒体库：选图 / 选视频 / 选音频，转为 [ComposerMediaResult]。
class ComposerMediaPicker {
  ComposerMediaPicker._();

  static const List<String> _audioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'opus',
    'flac',
  ];

  /// 底部菜单：选图片、选视频、选音频（自上而下）；取消返回 `null`。
  static Future<ComposerMediaResult?> showLibraryChoiceAndPick(
    BuildContext context,
  ) async {
    final kind = await showModalBottomSheet<_LibraryKind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('选图片'),
              onTap: () => Navigator.pop(ctx, _LibraryKind.image),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('选视频'),
              onTap: () => Navigator.pop(ctx, _LibraryKind.video),
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: const Text('选音频'),
              onTap: () => Navigator.pop(ctx, _LibraryKind.audio),
            ),
          ],
        ),
      ),
    );
    switch (kind) {
      case _LibraryKind.image:
        return pickGalleryImage();
      case _LibraryKind.video:
        return pickGalleryVideo();
      case _LibraryKind.audio:
        return pickAudioFile();
      case null:
        return null;
    }
  }

  static Future<ComposerMediaResult?> pickGalleryImage() async {
    final result =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (result == null) return null;
    final bytes = await result.readAsBytes();
    if (bytes.isEmpty) return null;
    final name = result.name;
    final mime = lookupMimeType(name, headerBytes: bytes) ?? 'image/jpeg';
    return ComposerMediaResult(
      bytes: Uint8List.fromList(bytes),
      fileName: name,
      mime: mime,
    );
  }

  static Future<ComposerMediaResult?> pickGalleryVideo() async {
    final result =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (result == null) return null;
    final bytes = await result.readAsBytes();
    if (bytes.isEmpty) return null;
    final name = result.name;
    final mime = lookupMimeType(name, headerBytes: bytes) ?? 'video/mp4';
    return ComposerMediaResult(
      bytes: Uint8List.fromList(bytes),
      fileName: name,
      mime: mime,
    );
  }

  static Future<ComposerMediaResult?> pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final name = picked.name;
    final mime = lookupMimeType(name, headerBytes: bytes) ?? 'audio/mpeg';
    return ComposerMediaResult(
      bytes: Uint8List.fromList(bytes),
      fileName: name,
      mime: mime,
    );
  }
}

enum _LibraryKind { image, video, audio }
