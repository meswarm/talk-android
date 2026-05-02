import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/media/media_preview_sizes.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  test('media preview sizes use separate defaults for bubble and table', () {
    expect(MediaPreviewSizes.bubbleDefaults.imageWidth, 260);
    expect(MediaPreviewSizes.bubbleDefaults.imageHeight, 220);
    expect(MediaPreviewSizes.bubbleDefaults.videoWidth, 260);
    expect(MediaPreviewSizes.bubbleDefaults.videoHeight, 220);
    expect(MediaPreviewSizes.bubbleDefaults.audioWidth, 320);
    expect(MediaPreviewSizes.bubbleDefaults.audioHeight, 64);
    expect(MediaPreviewSizes.bubbleDefaults.fileWidth, 320);
    expect(MediaPreviewSizes.bubbleDefaults.fileHeight, 64);

    expect(MediaPreviewSizes.tableDefaults.imageWidth, 96);
    expect(MediaPreviewSizes.tableDefaults.imageHeight, 72);
    expect(MediaPreviewSizes.tableDefaults.videoWidth, 96);
    expect(MediaPreviewSizes.tableDefaults.videoHeight, 72);
    expect(MediaPreviewSizes.tableDefaults.audioWidth, 240);
    expect(MediaPreviewSizes.tableDefaults.audioHeight, 44);
    expect(MediaPreviewSizes.tableDefaults.fileWidth, 180);
    expect(MediaPreviewSizes.tableDefaults.fileHeight, 44);
  });

  test('media preview sizes roundtrip through local storage', () async {
    final ls = LocalStorage();
    expect(
      await ls.loadBubbleMediaPreviewSizes(),
      MediaPreviewSizes.bubbleDefaults,
    );
    expect(
      await ls.loadTableMediaPreviewSizes(),
      MediaPreviewSizes.tableDefaults,
    );

    const bubble = MediaPreviewSizes(
      imageWidth: 210,
      imageHeight: 180,
      videoWidth: 220,
      videoHeight: 190,
      audioWidth: 300,
      audioHeight: 58,
      fileWidth: 280,
      fileHeight: 62,
    );
    const table = MediaPreviewSizes(
      imageWidth: 80,
      imageHeight: 64,
      videoWidth: 90,
      videoHeight: 68,
      audioWidth: 210,
      audioHeight: 40,
      fileWidth: 160,
      fileHeight: 42,
    );

    await ls.saveBubbleMediaPreviewSizes(bubble);
    await ls.saveTableMediaPreviewSizes(table);

    expect(await ls.loadBubbleMediaPreviewSizes(), bubble);
    expect(await ls.loadTableMediaPreviewSizes(), table);
  });

  test('markdown media context detects table media by source offset', () {
    const markdown = '''
普通图片 ![a](r2://b/room/imgs/1-a.png)

| 标题 | 详情 |
| --- | --- |
| A | ![b](r2://b/room/videos/1-b.mp4) |
''';

    final bubbleOffset = markdown.indexOf('r2://b/room/imgs/1-a.png');
    final tableOffset = markdown.indexOf('r2://b/room/videos/1-b.mp4');

    expect(
      markdownMediaPreviewContextForOffset(markdown, bubbleOffset),
      MediaPreviewContext.bubble,
    );
    expect(
      markdownMediaPreviewContextForOffset(markdown, tableOffset),
      MediaPreviewContext.table,
    );
  });
}
