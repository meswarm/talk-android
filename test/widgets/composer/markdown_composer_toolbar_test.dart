import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/widgets/composer/markdown_composer_toolbar.dart';

void main() {
  testWidgets('toolbar exposes 媒体库 and 相机 semantics, not legacy 图片/视频 labels',
      (tester) async {
    final controller = TextEditingController(text: 'x');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownComposerToolbar(
            enabled: true,
            previewing: false,
            composerText: controller,
            onTogglePreview: () {},
            onInsertCode: () {},
            onPickMediaLibrary: () {},
            onOpenCameraCapture: () {},
            onInsertFile: () {},
            onClearAll: () {},
            onCollapse: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('媒体库'), findsOneWidget);
    expect(find.bySemanticsLabel('相机'), findsOneWidget);
    expect(find.bySemanticsLabel('Insert image'), findsNothing);
    expect(find.bySemanticsLabel('Insert video'), findsNothing);
  });

  testWidgets('when disabled, 媒体库 and 相机 do not fire callbacks', (tester) async {
    final controller = TextEditingController(text: 'hi');
    var libraryCalls = 0;
    var cameraCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownComposerToolbar(
            enabled: false,
            previewing: false,
            composerText: controller,
            onTogglePreview: () {},
            onInsertCode: () {},
            onPickMediaLibrary: () => libraryCalls++,
            onOpenCameraCapture: () => cameraCalls++,
            onInsertFile: () {},
            onClearAll: () {},
            onCollapse: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('媒体库'));
    await tester.tap(find.byTooltip('相机'));
    await tester.pump();

    expect(libraryCalls, 0);
    expect(cameraCalls, 0);
  });
}
