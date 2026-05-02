import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  test('pinned room ids roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final ls = LocalStorage();

    await ls.savePinnedRoomIds(const ['!a:hs', '!b:hs']);
    final loaded = await ls.loadPinnedRoomIds();

    expect(loaded, ['!a:hs', '!b:hs']);
  });
}
