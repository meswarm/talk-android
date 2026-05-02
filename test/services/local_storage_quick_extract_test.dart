import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  test('room quick extract prompt roundtrips and clears when empty', () async {
    final ls = LocalStorage();
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '');

    await ls.saveRoomQuickExtractPrompt('!room:test', '提取第一列');
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '提取第一列');

    await ls.saveRoomQuickExtractPrompt('!room:test', '   ');
    expect(await ls.getRoomQuickExtractPrompt('!room:test'), '');
  });
}
