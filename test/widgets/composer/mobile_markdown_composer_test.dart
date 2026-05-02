import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/composer/mobile_markdown_composer.dart';
import 'package:talk/widgets/composer/markdown_source_editor.dart';
import 'package:talk/widgets/composer/markdown_syntax_text_editing_controller.dart';
import 'package:talk/widgets/markdown_renderer.dart';
import 'package:talk/widgets/r2_markdown_file_card.dart';

void main() {
  testWidgets('mobile composer toggles from source to preview and back',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(
            body: _ComposerToggleHarness(
              initialText: '# Title',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MarkdownSourceEditor), findsOneWidget);
    expect(find.byType(MarkdownRenderer), findsNothing);

    await tester.tap(find.byTooltip('Preview'));
    await tester.pump();

    expect(find.byType(MarkdownRenderer), findsOneWidget);

    await tester.tap(find.byTooltip('Edit source'));
    await tester.pump();

    expect(find.byType(MarkdownSourceEditor), findsOneWidget);
  });

  testWidgets('preview renders r2 file card and long press delete removes it',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(
            body: _ComposerToggleHarness(
              initialText: '[doc.pdf](r2://bucket/subhub/files/1-doc.pdf)',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Preview'));
    await tester.pumpAndSettle();

    expect(find.byType(R2MarkdownFileCard), findsOneWidget);

    await tester.longPress(find.byType(R2MarkdownFileCard));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.byType(R2MarkdownFileCard), findsNothing);
    expect(find.text('doc.pdf'), findsNothing);
  });
}

class _ComposerToggleHarness extends StatefulWidget {
  const _ComposerToggleHarness({required this.initialText});

  final String initialText;

  @override
  State<_ComposerToggleHarness> createState() => _ComposerToggleHarnessState();
}

class _ComposerToggleHarnessState extends State<_ComposerToggleHarness> {
  late final MarkdownSyntaxTextEditingController _controller;
  late final FocusNode _focusNode;
  ComposerViewMode _mode = ComposerViewMode.source;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownSyntaxTextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileMarkdownComposer(
      controller: _controller,
      focusNode: _focusNode,
      isDark: false,
      panelHeight: 500,
      composerHeightPct: 50,
      viewMode: _mode,
      onTogglePreview: () {
        setState(() {
          _mode = _mode == ComposerViewMode.source
              ? ComposerViewMode.preview
              : ComposerViewMode.source;
        });
      },
      uploadingMedia: false,
      onChanged: (_) {},
      onInsertCode: () {},
      onPickMediaLibrary: () {},
      onOpenCameraCapture: () {},
      onInsertFile: () {},
      onClearAll: () {},
      onCollapse: () {},
      onHeightPctChanged: (_) {},
    );
  }
}
