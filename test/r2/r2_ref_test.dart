import 'package:flutter_test/flutter_test.dart';
import 'package:talk/r2/r2_ref.dart';

void main() {
  test('parseR2Ref basic', () {
    expect(
      parseR2Ref('r2://my-bucket/path/to/obj.bin'),
      isA<ParsedR2Ref>()
          .having((p) => p.bucket, 'bucket', 'my-bucket')
          .having((p) => p.objectKey, 'objectKey', 'path/to/obj.bin'),
    );
  });

  test('parseR2Ref with mime query', () {
    final p = parseR2Ref('r2://b/k?mime=image%2Fpng');
    expect(p?.mimeHint, 'image/png');
    expect(p?.bucket, 'b');
    expect(p?.objectKey, 'k');
  });

  test('parseR2Ref rejects https', () {
    expect(parseR2Ref('https://x/y'), isNull);
  });

  test('buildR2Ref has no mime query (third arg ignored)', () {
    final r = buildR2Ref('b', 'a/c', 'image/jpeg');
    expect(r, 'r2://b/a/c');
    expect(r.contains('?'), isFalse);
    final p = parseR2Ref(r);
    expect(p?.bucket, 'b');
    expect(p?.objectKey, 'a/c');
  });

  test('r2RefWithoutQuery strips query', () {
    expect(
      r2RefWithoutQuery('r2://b/k?mime=x'),
      'r2://b/k',
    );
  });

  test('buildAttachmentObjectKey shape', () {
    final k = buildAttachmentObjectKey('my photo.png');
    expect(k.startsWith('attachments/'), isTrue);
    expect(k.contains('my'), isTrue);
  });

  test('attachmentDirFromMime maps to imgs videos audios files', () {
    expect(attachmentDirFromMime('image/png'), 'imgs');
    expect(attachmentDirFromMime('video/mp4'), 'videos');
    expect(attachmentDirFromMime('audio/mpeg'), 'audios');
    expect(attachmentDirFromMime('application/pdf'), 'files');
  });

  test('buildRoomAttachmentObjectKey includes prefix and category', () {
    final k = buildRoomAttachmentObjectKey(
      roomPrefix: 'team/a',
      fileName: 'x.png',
      mime: 'image/png',
    );
    expect(k.startsWith('team/a/imgs/'), isTrue);
    expect(k.contains('x.png') || k.contains('x'), isTrue);
  });

  test('inferR2MediaKind directory wins over extension', () {
    expect(
      inferR2MediaKind('r2://b/room/videos/1-thumb.PNG'),
      R2MediaKind.video,
    );
    expect(
      inferR2MediaKind('r2://b/prefix/files/1-doc.png'),
      R2MediaKind.file,
    );
  });

  test('inferR2MediaKind falls back to extension without category dir', () {
    expect(
      inferR2MediaKind('r2://bucket/attachments/177-x.mp4'),
      R2MediaKind.video,
    );
    expect(
      inferR2MediaKind('r2://bucket/attachments/177-x.jpg'),
      R2MediaKind.image,
    );
    expect(
      inferR2MediaKind('r2://bucket/attachments/t.aac'),
      R2MediaKind.audio,
    );
  });

  test('r2MarkdownSnippet audio uses image markdown syntax', () {
    expect(
      r2MarkdownSnippet('a.mp3', 'audio/mpeg', 'r2://b/room/audios/1-a.mp3'),
      '![a.mp3（音频）](r2://b/room/audios/1-a.mp3)',
    );
  });

  test('rewriteR2AudioBracketLinksToImageMarkdown upgrades bracket audio only',
      () {
    const before = '[song（音频）](r2://b/p/a.mp3)\n[doc](r2://b/p/f.pdf)';
    const after = '![song（音频）](r2://b/p/a.mp3)\n[doc](r2://b/p/f.pdf)';
    expect(rewriteR2AudioBracketLinksToImageMarkdown(before), after);
  });

  test('inferR2MediaKind ignores mime query for classification', () {
    expect(
      inferR2MediaKind(
        'r2://bucket/matrix/attachments/x-capture.mp4?mime=video%2Fmp4',
      ),
      R2MediaKind.video,
    );
    expect(
      inferR2MediaKind('r2://bucket/attachments/file?mime=video%2Fmp4'),
      R2MediaKind.unknown,
    );
  });
}
