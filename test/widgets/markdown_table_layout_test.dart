import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/markdown_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const markdown = '''
| 金额 | 周期 | 下次扣款日 | 备注 |
| --- | --- | --- | --- |
| ￥10.90 | 月付 | 2026-05-06 | 每月自动续费，最近扣款提示 |
''';

  testWidgets('markdown table uses at least bubble width as min width', (
    tester,
  ) async {
    const bubbleWidth = 300.0;

    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: bubbleWidth,
              child: MarkdownRenderer(data: markdown, isDark: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);

    final constrainedTable = find.descendant(
      of: horizontalScroll,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == bubbleWidth,
      ),
    );
    expect(constrainedTable, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('markdown table keeps a trailing scroll gutter', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: MarkdownRenderer(data: markdown, isDark: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);

    final trailingGutter = find.descendant(
      of: horizontalScroll,
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 14,
      ),
    );
    expect(trailingGutter, findsOneWidget);
  });

  testWidgets('markdown table uses compact cell padding', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(body: MarkdownRenderer(data: markdown, isDark: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final compactPadding = find.descendant(
      of: find.byType(Table),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(4, 4, 4, 4),
      ),
    );

    expect(compactPadding, findsWidgets);
  });

  testWidgets('markdown table caps each column width for wrapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(body: MarkdownRenderer(data: markdown, isDark: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final table = tester.widget<Table>(find.byType(Table));
    final widths = table.columnWidths!;
    expect(widths.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(widths[i], isA<MinColumnWidth>());
    }
  });
}
