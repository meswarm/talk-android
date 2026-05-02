import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';
import 'package:talk/widgets/chat_video_preview_card.dart';
import 'package:talk/widgets/fullscreen_video_player_route.dart';

void main() {
  testWidgets('tapping the central play button triggers onPlay', (tester) async {
    var played = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatVideoPreviewCard(
            duration: const Duration(seconds: 28),
            onPlay: () => played = true,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(played, isTrue);
  });

  testWidgets('tapping outside the play button does not trigger onPlay',
      (tester) async {
    var played = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatVideoPreviewCard(
            duration: const Duration(seconds: 28),
            onPlay: () => played = true,
            child: const SizedBox(width: 220, height: 140),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getTopLeft(find.byType(ChatVideoPreviewCard)) +
        const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(played, isFalse);
  });

  testWidgets('play button can open the fullscreen route', (tester) async {
    const source = FullscreenVideoSource(
      filePath: '/tmp/demo.mp4',
      heroTag: 'vid-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ChatVideoPreviewCard(
            duration: const Duration(seconds: 28),
            onPlay: () => openFullscreenVideoPlayer(context, source: source),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenVideoPlayerPage), findsOneWidget);
  });

  testWidgets('video bubble keeps fullscreen entry on the play button only',
      (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 160,
            child: ChatVideoPreviewCard(
              duration: const Duration(seconds: 28),
              onPlay: () => opened = true,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getTopLeft(find.byType(ChatVideoPreviewCard)) +
        const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(opened, isFalse);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}
