import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/services/local_storage.dart';
import 'package:talk/widgets/common_phrases_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  testWidgets('picking common phrase calls onPick', (tester) async {
    await LocalStorage().saveRoomCommonPhrases('!a:hs', ['今天我有哪些任务？']);
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonPhrasesSheet(
            storage: LocalStorage(),
            roomId: '!a:hs',
            onPick: (value) => picked = value,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('今天我有哪些任务？'));
    await tester.pumpAndSettle();

    expect(picked, '今天我有哪些任务？');
  });

  testWidgets('editing common phrases saves local list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommonPhrasesSheet(
            storage: LocalStorage(),
            roomId: '!a:hs',
            onPick: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加常用语'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '常用语 1'), '马上处理');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final phrases = await LocalStorage().loadRoomCommonPhrases('!a:hs');
    expect(phrases.first, '马上处理');
    expect(await LocalStorage().loadRoomCommonPhrases('!b:hs'), isEmpty);
  });
}
