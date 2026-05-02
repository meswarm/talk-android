import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/expandable_markdown_body.dart';

String _longMarkdownBody() {
  return List.generate(
    60,
    (i) => 'Line $i of long markdown body for overflow.',
  ).join('\n');
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  testWidgets(
    'autoCollapseEnabled false shows full markdown without expand bar',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<R2Service>(
          create: (_) => R2Service(),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExpandableMarkdownBody(
                  data: _longMarkdownBody(),
                  isDark: false,
                  isOwnMessage: false,
                  maxHeight: 80,
                  bubbleColor: Colors.white,
                  autoCollapseEnabled: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('展开'), findsNothing);
      expect(find.byTooltip('折叠'), findsNothing);
    },
  );

  testWidgets('autoCollapseEnabled true shows expand when content overflows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpandableMarkdownBody(
                data: _longMarkdownBody(),
                isDark: false,
                isOwnMessage: false,
                maxHeight: 80,
                bubbleColor: Colors.white,
                autoCollapseEnabled: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开'), findsOneWidget);

    await tester.tap(find.byTooltip('展开'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('折叠'), findsOneWidget);
  });

  testWidgets('data change resets expanded state', (tester) async {
    var markdown = _longMarkdownBody();

    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setLocalState) => Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        setLocalState(() {
                          markdown = 'short body';
                        });
                      },
                      child: const Text('swap'),
                    ),
                    ExpandableMarkdownBody(
                      data: markdown,
                      isDark: false,
                      isOwnMessage: false,
                      maxHeight: 80,
                      bubbleColor: Colors.white,
                      autoCollapseEnabled: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开'), findsOneWidget);
    await tester.tap(find.byTooltip('展开'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('折叠'), findsOneWidget);

    await tester.tap(find.text('swap'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开'), findsNothing);
    expect(find.byTooltip('折叠'), findsNothing);
    expect(find.text('short body'), findsOneWidget);
  });
}
