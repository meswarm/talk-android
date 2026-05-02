import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';
import 'package:talk/widgets/fullscreen_video_player_route.dart';

void main() {
  testWidgets('openFullscreenVideoPlayer uses an instant route transition', (
    tester,
  ) async {
    final observer = _RouteCaptureObserver();
    const source = FullscreenVideoSource(
      filePath: '/tmp/demo.mp4',
      heroTag: 'vid-1',
      durationHint: Duration(seconds: 28),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openFullscreenVideoPlayer(context, source: source),
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

  testWidgets('openFullscreenVideoPlayer pushes the video player page', (
    tester,
  ) async {
    const source = FullscreenVideoSource(
      filePath: '/tmp/demo.mp4',
      heroTag: 'vid-1',
      durationHint: Duration(seconds: 28),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openFullscreenVideoPlayer(context, source: source),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenVideoPlayerPage), findsOneWidget);
  });

  test('FullscreenVideoSource preserves its fields', () {
    const source = FullscreenVideoSource(
      filePath: '/tmp/demo.mp4',
      heroTag: 'vid-1',
      durationHint: Duration(minutes: 1),
      ownsFile: true,
      title: '视频',
    );

    expect(source.filePath, '/tmp/demo.mp4');
    expect(source.heroTag, 'vid-1');
    expect(source.durationHint, const Duration(minutes: 1));
    expect(source.ownsFile, isTrue);
    expect(source.title, '视频');
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
