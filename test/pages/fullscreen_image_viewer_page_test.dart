import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_image_source.dart';
import 'package:talk/pages/fullscreen_image_viewer_page.dart';

void main() {
  Widget buildPage() {
    return MaterialApp(
      home: FullscreenImageViewerPage(
        source: FullscreenImageSource.memory(
          bytes: Uint8List.fromList(const [0, 1, 2, 3]),
          heroTag: 'img-1',
        ),
      ),
    );
  }

  testWidgets('single tap toggles toolbar visibility', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byType(InteractiveViewer));
    // With onDoubleTap registered, onTap waits past the double-tap window.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('switching to fit-width updates the selected mode label',
      (tester) async {
    await tester.pumpWidget(buildPage());

    await tester.tap(find.text('适应屏幕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('适应宽度').last);
    await tester.pumpAndSettle();

    expect(find.text('适应宽度'), findsWidgets);
  });

  testWidgets('double tap zooms in from base scale', (tester) async {
    await tester.pumpWidget(buildPage());

    final viewer = find.byType(InteractiveViewer);
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();

    final state = tester.state<FullscreenImageViewerPageState>(
      find.byType(FullscreenImageViewerPage),
    );
    expect(state.transformController.value.getMaxScaleOnAxis(), greaterThan(1));
  });

  testWidgets('switching display mode resets the transform to identity',
      (tester) async {
    await tester.pumpWidget(buildPage());

    final state = tester.state<FullscreenImageViewerPageState>(
      find.byType(FullscreenImageViewerPage),
    );
    state.transformController.value = Matrix4.diagonal3Values(2.2, 2.2, 1);
    await tester.pump();

    await tester.tap(find.text('适应屏幕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('适应宽度').last);
    await tester.pumpAndSettle();

    expect(state.transformController.value, Matrix4.identity());
  });
}
