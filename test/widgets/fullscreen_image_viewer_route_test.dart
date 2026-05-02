import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_image_source.dart';
import 'package:talk/pages/fullscreen_image_viewer_page.dart';
import 'package:talk/widgets/fullscreen_image_viewer_route.dart';

void main() {
  testWidgets('openFullscreenImageViewer uses an instant route transition', (
    tester,
  ) async {
    final observer = _RouteCaptureObserver();
    final bytes = Uint8List.fromList(const [0, 1, 2, 3]);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              openFullscreenImageViewer(
                context,
                source: FullscreenImageSource.memory(
                  bytes: bytes,
                  heroTag: 'mem-1',
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    final route = observer.lastPushed;
    expect(route, isA<PageRoute<dynamic>>());
    final pageRoute = route! as PageRoute<dynamic>;
    expect(pageRoute.transitionDuration, Duration.zero);
    expect(pageRoute.reverseTransitionDuration, Duration.zero);
  });

  testWidgets(
    'openFullscreenImageViewer pushes the viewer page for memory images',
    (tester) async {
      final bytes = Uint8List.fromList(const [0, 1, 2, 3]);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                openFullscreenImageViewer(
                  context,
                  source: FullscreenImageSource.memory(
                    bytes: bytes,
                    heroTag: 'mem-1',
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
    },
  );

  test('asset and network constructors preserve their fields', () {
    const asset = FullscreenImageSource.asset(
      assetName: 'assets/demo.png',
      heroTag: 'asset-1',
    );
    const net = FullscreenImageSource.network(
      url: 'https://example.com/demo.png',
      heroTag: 'net-1',
    );

    expect(asset.assetName, 'assets/demo.png');
    expect(asset.kind, FullscreenImageSourceKind.asset);
    expect(net.url, 'https://example.com/demo.png');
    expect(net.kind, FullscreenImageSourceKind.network);
  });
}

class _RouteCaptureObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}
