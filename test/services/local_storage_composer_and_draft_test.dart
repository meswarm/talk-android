import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  test('composer height pct clamps and roundtrips', () async {
    final ls = LocalStorage();

    await ls.saveComposerHeightPct(99);
    expect(await ls.loadComposerHeightPct(), LocalStorage.maxComposerHeightPct);

    await ls.saveComposerHeightPct(10);
    expect(await ls.loadComposerHeightPct(), LocalStorage.minComposerHeightPct);

    await ls.saveComposerHeightPct(42);
    expect(await ls.loadComposerHeightPct(), 42);
  });

  test('room note per room roundtrips and clears when empty', () async {
    final ls = LocalStorage();
    expect(await ls.getRoomNote('!a:hs'), '');

    await ls.saveRoomNote('!a:hs', '  hello  ');
    expect(await ls.getRoomNote('!a:hs'), '  hello  ');

    await ls.saveRoomNote('!b:hs', 'other');
    expect(await ls.getRoomNote('!a:hs'), '  hello  ');
    expect(await ls.getRoomNote('!b:hs'), 'other');

    await ls.saveRoomNote('!a:hs', '   ');
    expect(await ls.getRoomNote('!a:hs'), '');
  });

  test('compress upload images defaults on and roundtrips', () async {
    final ls = LocalStorage();
    expect(await ls.loadCompressUploadImages(), true);

    await ls.saveCompressUploadImages(false);
    expect(await ls.loadCompressUploadImages(), false);

    await ls.saveCompressUploadImages(true);
    expect(await ls.loadCompressUploadImages(), true);
  });

  test('voice keep alive defaults off and roundtrips', () async {
    final ls = LocalStorage();
    expect(await ls.loadVoiceKeepAliveEnabled(), false);

    await ls.saveVoiceKeepAliveEnabled(true);
    expect(await ls.loadVoiceKeepAliveEnabled(), true);

    await ls.saveVoiceKeepAliveEnabled(false);
    expect(await ls.loadVoiceKeepAliveEnabled(), false);
  });

  test('room common phrases default empty save and isolate by room', () async {
    final ls = LocalStorage();
    expect(await ls.loadRoomCommonPhrases('!a:hs'), isEmpty);

    await ls.saveRoomCommonPhrases('!a:hs', ['  好的  ', '', '稍后处理']);
    expect(await ls.loadRoomCommonPhrases('!a:hs'), ['好的', '稍后处理']);
    expect(await ls.loadRoomCommonPhrases('!b:hs'), isEmpty);

    await ls.saveRoomCommonPhrases('!a:hs', []);
    expect(await ls.loadRoomCommonPhrases('!a:hs'), isEmpty);
  });

  test('bubble max height pct clamps and roundtrips', () async {
    final ls = LocalStorage();

    expect(
      await ls.loadBubbleMaxHeightPct(),
      LocalStorage.defaultBubbleMaxHeightPct,
    );

    await ls.saveBubbleMaxHeightPct(99);
    expect(
      await ls.loadBubbleMaxHeightPct(),
      LocalStorage.maxBubbleMaxHeightPct,
    );

    await ls.saveBubbleMaxHeightPct(5);
    expect(
      await ls.loadBubbleMaxHeightPct(),
      LocalStorage.minBubbleMaxHeightPct,
    );

    await ls.saveBubbleMaxHeightPct(40);
    expect(await ls.loadBubbleMaxHeightPct(), 40);
  });

  test('composer height migrates from legacy int key', () async {
    SharedPreferences.setMockInitialValues({'talk_composer_height_pct': 33});
    LocalStorage().resetPrefsCacheForTest();
    final ls = LocalStorage();
    expect(await ls.loadComposerHeightPct(), 33);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('talkweb_composer_height_pct'), 33);
    expect(p.containsKey('talk_composer_height_pct'), isFalse);
  });

  test('draft migrates from legacy draft_ prefix', () async {
    SharedPreferences.setMockInitialValues({'draft_!r:hs': 'hello'});
    LocalStorage().resetPrefsCacheForTest();
    final ls = LocalStorage();
    expect(await ls.getDraft('!r:hs'), 'hello');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('talkweb_draft_!r:hs'), 'hello');
    expect(p.containsKey('draft_!r:hs'), isFalse);
  });

  test('room auto collapse defaults on and is isolated per room', () async {
    final ls = LocalStorage();
    expect(await ls.loadRoomAutoCollapseEnabled('!a:hs'), true);
    expect(await ls.loadRoomAutoCollapseEnabled('!b:hs'), true);

    await ls.saveRoomAutoCollapseEnabled('!a:hs', false);
    expect(await ls.loadRoomAutoCollapseEnabled('!a:hs'), false);
    expect(await ls.loadRoomAutoCollapseEnabled('!b:hs'), true);

    await ls.saveRoomAutoCollapseEnabled('!a:hs', true);
    expect(await ls.loadRoomAutoCollapseEnabled('!a:hs'), true);
  });
}
