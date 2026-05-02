import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/expandable_markdown_body.dart';
import 'package:talk/widgets/markdown_renderer.dart';
import 'package:talk/widgets/markdown_selection_menu.dart';

class _MockClipboard {
  dynamic clipboardData = <String, dynamic>{'text': null};

  Future<Object?> handleMethodCall(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Clipboard.getData':
        return clipboardData;
      case 'Clipboard.hasStrings':
        final clipboardDataMap = clipboardData as Map<String, dynamic>?;
        final text = clipboardDataMap?['text'] as String?;
        return <String, bool>{'value': text != null && text.isNotEmpty};
      case 'Clipboard.setData':
        clipboardData = methodCall.arguments;
    }
    return null;
  }
}

Offset _textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const caret = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final localOffset =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caret) +
      Offset(0.0, paragraph.preferredLineHeight);
  return paragraph.localToGlobal(localOffset) + const Offset(0.0, -2.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clipboard = _MockClipboard();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          clipboard.handleMethodCall,
        );
    await Clipboard.setData(const ClipboardData(text: ''));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('markdown selection menu copies selected text', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const Scaffold(
            body: MarkdownRenderer(data: '您好！我是您的个人订阅管理助手。', isDark: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('您好！我是您的个人订阅管理助手。'),
        matching: find.byType(RichText),
      ),
    );

    final gesture = await tester.startGesture(
      _textOffsetToPosition(paragraph, 7),
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('复制'), findsOneWidget);
    expect(find.byType(TextSelectionToolbarTextButton), findsNothing);

    final buttonCenter = tester.getCenter(find.text('复制'));
    final tapGesture = await tester.startGesture(buttonCenter);
    await tester.pump();

    var clipboardData = clipboard.clipboardData as Map<String, dynamic>;
    expect((clipboardData['text'] as String?)?.isNotEmpty, isTrue);

    await tapGesture.up();
    await tester.pump();

    clipboardData = clipboard.clipboardData as Map<String, dynamic>;
    expect((clipboardData['text'] as String?)?.isNotEmpty, isTrue);
  });

  testWidgets(
    'markdown selection menu copies bubble markdown source on Android',
    (tester) async {
      const sourceMarkdown = '**hello** [file](r2://bucket/files/a.pdf)';
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: const Scaffold(
            body: MarkdownSelectionArea(
              sourceMarkdown: sourceMarkdown,
              child: Text('rendered bubble text'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('rendered bubble text'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('复制气泡'), findsOneWidget);

      final buttonCenter = tester.getCenter(find.text('复制气泡'));
      final tapGesture = await tester.startGesture(buttonCenter);
      await tester.pump();

      final clipboardData = clipboard.clipboardData as Map<String, dynamic>;
      expect(clipboardData['text'], sourceMarkdown);

      await tapGesture.up();
      await tester.pump();
    },
  );

  testWidgets('markdown selection menu copies selected text on iOS', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(
            body: MarkdownRenderer(data: '您好！我是您的个人订阅管理助手。', isDark: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('您好！我是您的个人订阅管理助手。'),
        matching: find.byType(RichText),
      ),
    );

    final gesture = await tester.startGesture(
      _textOffsetToPosition(paragraph, 7),
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('复制'), findsOneWidget);
    expect(find.byType(CupertinoTextSelectionToolbarButton), findsNothing);

    final buttonCenter = tester.getCenter(find.text('复制'));
    final tapGesture = await tester.startGesture(buttonCenter);
    await tester.pump();
    await tapGesture.up();
    await tester.pump();

    final clipboardData = clipboard.clipboardData as Map<String, dynamic>;
    expect((clipboardData['text'] as String?)?.isNotEmpty, isTrue);
  });

  testWidgets(
    'markdown selection menu copies text inside expandable body on iOS',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<R2Service>(
          create: (_) => R2Service(),
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const Scaffold(
              body: ExpandableMarkdownBody(
                data: '您好！我是您的个人订阅管理助手。您可以查询当前订阅、新增或删除记录。',
                isDark: false,
                isOwnMessage: false,
                maxHeight: 600,
                bubbleColor: Colors.white,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('您好！我是您的个人订阅管理助手。您可以查询当前订阅、新增或删除记录。'),
          matching: find.byType(RichText),
        ),
      );

      final gesture = await tester.startGesture(
        _textOffsetToPosition(paragraph, 7),
      );
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('复制'), findsOneWidget);

      final buttonCenter = tester.getCenter(find.text('复制'));
      final tapGesture = await tester.startGesture(buttonCenter);
      await tester.pump();
      await tapGesture.up();
      await tester.pump();

      final clipboardData = clipboard.clipboardData as Map<String, dynamic>;
      expect((clipboardData['text'] as String?)?.isNotEmpty, isTrue);
    },
  );
}
