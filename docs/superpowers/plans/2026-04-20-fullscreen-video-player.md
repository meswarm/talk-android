# Fullscreen Video Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated fullscreen video player for chat videos so the bubble becomes a preview-only card with a play button, and actual playback happens in a dark fullscreen page with play / pause, seek, and time labels.

**Architecture:** Reuse the existing attachment download path in `EventMediaContent`, but split video responsibilities into three focused pieces: a normalized fullscreen video source plus route helper, a preview-only bubble card, and a dedicated fullscreen page that owns its own `VideoPlayerController`. Keep tests stable by injecting a fake controller factory into the fullscreen page rather than depending on platform video plugins in widget tests.

**Tech Stack:** Flutter, Dart, `video_player`, existing Matrix attachment flow, `flutter_test`

---

## File Structure

### Create

- `lib/media/fullscreen_video_source.dart`
  - Defines the normalized local-file-backed fullscreen video source and ownership flags for cleanup.
- `lib/widgets/fullscreen_video_player_route.dart`
  - Hosts the shared `openFullscreenVideoPlayer(...)` helper used by chat video bubbles.
- `lib/widgets/chat_video_preview_card.dart`
  - Renders the non-playing bubble preview surface with thumbnail, play button, and duration badge.
- `lib/pages/fullscreen_video_player_page.dart`
  - Hosts the dark fullscreen player layout, controller lifecycle, controls, seek logic, and cleanup.
- `lib/widgets/fullscreen_video_control_bar.dart`
  - Focused bottom control strip for play / pause, time labels, and seek bar.
- `test/widgets/fullscreen_video_player_route_test.dart`
  - Verifies normalized source fields and route push behavior.
- `test/widgets/chat_video_preview_card_test.dart`
  - Verifies bubble preview interaction rules and route-opening behavior from the play button.
- `test/pages/fullscreen_video_player_page_test.dart`
  - Verifies fullscreen control visibility, auto-play, play / pause, seek behavior, and cleanup through a fake controller.

### Modify

- `lib/widgets/event_media_content.dart`
  - Replace inline bubble video playback with preview-card rendering and wire the play button to the fullscreen player route.

### Existing References To Read During Execution

- `lib/widgets/event_media_content.dart`
  - Current attachment loading, temporary file materialization, and inline video branch.
- `lib/pages/fullscreen_image_viewer_page.dart`
  - Existing fullscreen media-page structure, dark layout, and tap-to-toggle toolbar behavior.
- `test/widgets/r2_markdown_image_fullscreen_test.dart`
  - Existing fullscreen media navigation test patterns in this repo.

## Task 1: Create the normalized fullscreen video source and route helper

**Files:**
- Create: `lib/media/fullscreen_video_source.dart`
- Create: `lib/widgets/fullscreen_video_player_route.dart`
- Create: `lib/pages/fullscreen_video_player_page.dart`
- Create: `test/widgets/fullscreen_video_player_route_test.dart`

- [ ] **Step 1: Write the failing route-helper tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';
import 'package:talk/widgets/fullscreen_video_player_route.dart';

void main() {
  testWidgets('openFullscreenVideoPlayer pushes the video player page',
      (tester) async {
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
```

- [ ] **Step 2: Run the route-helper tests and verify they fail**

Run: `flutter test test/widgets/fullscreen_video_player_route_test.dart -r expanded`

Expected: FAIL because `FullscreenVideoSource`, `openFullscreenVideoPlayer`, and `FullscreenVideoPlayerPage` do not exist yet.

- [ ] **Step 3: Add the normalized local-file video source**

```dart
class FullscreenVideoSource {
  const FullscreenVideoSource({
    required this.filePath,
    required this.heroTag,
    this.durationHint,
    this.ownsFile = false,
    this.title = '视频',
  });

  final String filePath;
  final Object heroTag;
  final Duration? durationHint;
  final bool ownsFile;
  final String title;
}
```

- [ ] **Step 4: Add the shared route helper and a temporary page stub**

In `lib/widgets/fullscreen_video_player_route.dart`:

```dart
import 'package:flutter/material.dart';

import '../media/fullscreen_video_source.dart';
import '../pages/fullscreen_video_player_page.dart';

Future<void> openFullscreenVideoPlayer(
  BuildContext context, {
  required FullscreenVideoSource source,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => FullscreenVideoPlayerPage(source: source),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}
```

In `lib/pages/fullscreen_video_player_page.dart`, add a compile-only stub that Task 3 will replace:

```dart
import 'package:flutter/material.dart';

import '../media/fullscreen_video_source.dart';

class FullscreenVideoPlayerPage extends StatelessWidget {
  const FullscreenVideoPlayerPage({super.key, required this.source});

  final FullscreenVideoSource source;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(source.title)),
      body: const Center(child: Text('stub')),
    );
  }
}
```

- [ ] **Step 5: Re-run the route-helper tests**

Run: `flutter test test/widgets/fullscreen_video_player_route_test.dart -r expanded`

Expected: PASS once the source model, route helper, and stub page compile.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/media/fullscreen_video_source.dart \
  lib/widgets/fullscreen_video_player_route.dart \
  lib/pages/fullscreen_video_player_page.dart \
  test/widgets/fullscreen_video_player_route_test.dart
git commit -m "feat: add fullscreen video player route helper"
```

## Task 2: Replace inline bubble playback with a preview-only video card

**Files:**
- Create: `lib/widgets/chat_video_preview_card.dart`
- Modify: `lib/widgets/event_media_content.dart`
- Create: `test/widgets/chat_video_preview_card_test.dart`

- [ ] **Step 1: Write the failing preview-card tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/widgets/chat_video_preview_card.dart';
import 'package:talk/widgets/fullscreen_video_player_route.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';

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

    await tester.tap(find.byType(ChatVideoPreviewCard));
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
}
```

- [ ] **Step 2: Run the preview-card tests and verify they fail**

Run: `flutter test test/widgets/chat_video_preview_card_test.dart -r expanded`

Expected: FAIL because `ChatVideoPreviewCard` does not exist and `EventMediaContent` still expects inline playback behavior.

- [ ] **Step 3: Add the preview-only bubble card**

In `lib/widgets/chat_video_preview_card.dart`:

```dart
import 'package:flutter/material.dart';

class ChatVideoPreviewCard extends StatelessWidget {
  const ChatVideoPreviewCard({
    super.key,
    required this.child,
    required this.duration,
    required this.onPlay,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onPlay;

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.black26),
            ),
          ),
          IconButton(
            iconSize: 58,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _format(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Replace inline bubble video playback with the preview card**

In `lib/widgets/event_media_content.dart`, update the `MessageTypes.Video` branch:

```dart
case MessageTypes.Video:
  final v = _video;
  final path = _tempVideoPath;
  if (v == null || !v.value.isInitialized || path == null) {
    return Text(
      '[视频解码中…]',
      style: TextStyle(fontSize: 13, color: subtext),
    );
  }
  final ar = v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio;
  return AspectRatio(
    aspectRatio: ar,
    child: ChatVideoPreviewCard(
      duration: v.value.duration,
      onPlay: () {
        openFullscreenVideoPlayer(
          context,
          source: FullscreenVideoSource(
            filePath: path,
            heroTag: 'event-video-${widget.event.eventId}',
            durationHint: v.value.duration,
            ownsFile: false,
          ),
        );
      },
      child: Hero(
        tag: 'event-video-${widget.event.eventId}',
        child: VideoPlayer(v),
      ),
    ),
  );
```

Also add imports:

```dart
import '../media/fullscreen_video_source.dart';
import 'chat_video_preview_card.dart';
import 'fullscreen_video_player_route.dart';
```

- [ ] **Step 5: Re-run the preview-card tests**

Run: `flutter test test/widgets/chat_video_preview_card_test.dart -r expanded`

Expected: PASS for play-button-only interaction and route-opening behavior.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/widgets/chat_video_preview_card.dart \
  lib/widgets/event_media_content.dart \
  test/widgets/chat_video_preview_card_test.dart
git commit -m "feat: show preview-only chat video cards"
```

## Task 3: Build the fullscreen video page shell with injectable controller creation

**Files:**
- Modify: `lib/pages/fullscreen_video_player_page.dart`
- Create: `lib/widgets/fullscreen_video_control_bar.dart`
- Create: `test/pages/fullscreen_video_player_page_test.dart`

- [ ] **Step 1: Write the failing fullscreen-page tests with a fake controller**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';

class FakeVideoController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoController()
      : super(
          const VideoPlayerValue(
            duration: Duration(seconds: 28),
            size: Size(320, 180),
            isInitialized: false,
          ),
        );

  bool played = false;
  bool paused = false;
  bool disposed = false;

  @override
  int playerId = 1;

  @override
  String get dataSource => '/tmp/demo.mp4';

  @override
  DataSourceType get dataSourceType => DataSourceType.file;

  @override
  Map<String, String> get httpHeaders => const {};

  @override
  String get package => '';

  @override
  VideoFormat? get formatHint => null;

  @override
  VideoPlayerOptions? get videoPlayerOptions => null;

  @override
  VideoViewType get viewType => VideoViewType.textureView;

  @override
  Future<void> initialize() async {
    value = value.copyWith(isInitialized: true);
  }

  @override
  Future<void> play() async {
    played = true;
    paused = false;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    paused = true;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration moment) async {
    value = value.copyWith(position: moment);
  }

  @override
  Future<Duration> get position async => value.position;

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setClosedCaptionFile(Future<ClosedCaptionFile>? file) async {}

  @override
  Future<ClosedCaptionFile> get closedCaptionFile async =>
      throw UnimplementedError();

  @override
  Future<List<VideoAudioTrack>> getAudioTracks() async => const [];

  @override
  Future<void> selectAudioTrack(String trackId) async {}

  @override
  bool isAudioTrackSupportAvailable() => false;

  @override
  void setCaptionOffset(Duration delay) {}
}

void main() {
  testWidgets('page auto-plays after initialize', (tester) async {
    final fake = FakeVideoController();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenVideoPlayerPage(
          source: const FullscreenVideoSource(
            filePath: '/tmp/demo.mp4',
            heroTag: 'vid-1',
          ),
          controllerFactory: (_) => fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.played, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('single tap toggles the controls', (tester) async {
    final fake = FakeVideoController();

    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenVideoPlayerPage(
          source: const FullscreenVideoSource(
            filePath: '/tmp/demo.mp4',
            heroTag: 'vid-1',
          ),
          controllerFactory: (_) => fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byType(FullscreenVideoPlayerPage));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
```

- [ ] **Step 2: Run the fullscreen-page tests and verify they fail**

Run: `flutter test test/pages/fullscreen_video_player_page_test.dart -r expanded`

Expected: FAIL because the page stub has no controller factory, no play / pause UI, and no tap-to-toggle controls.

- [ ] **Step 3: Add the focused bottom control bar widget**

In `lib/widgets/fullscreen_video_control_bar.dart`:

```dart
import 'package:flutter/material.dart';

class FullscreenVideoControlBar extends StatelessWidget {
  const FullscreenVideoControlBar({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.progressValue,
    required this.onPlayPause,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double progressValue;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.56)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: onPlayPause,
              color: Colors.white,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Text(_format(position), style: const TextStyle(color: Colors.white)),
            Expanded(
              child: Slider(
                value: progressValue,
                onChanged: onChanged,
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
              ),
            ),
            Text(_format(duration), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace the stub page with the real fullscreen shell**

In `lib/pages/fullscreen_video_player_page.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../media/fullscreen_video_source.dart';
import '../widgets/fullscreen_video_control_bar.dart';

typedef FullscreenVideoControllerFactory = VideoPlayerController Function(
  FullscreenVideoSource source,
);

class FullscreenVideoPlayerPage extends StatefulWidget {
  const FullscreenVideoPlayerPage({
    super.key,
    required this.source,
    this.controllerFactory,
  });

  final FullscreenVideoSource source;
  final FullscreenVideoControllerFactory? controllerFactory;

  @override
  State<FullscreenVideoPlayerPage> createState() =>
      FullscreenVideoPlayerPageState();
}

class FullscreenVideoPlayerPageState extends State<FullscreenVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _controlsVisible = true;
  String? _error;

  VideoPlayerController _createController() {
    final factory = widget.controllerFactory;
    if (factory != null) return factory(widget.source);
    return VideoPlayerController.file(File(widget.source.filePath));
  }

  Future<void> _init() async {
    final controller = _createController();
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      controller.addListener(_handleControllerChanged);
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_handleControllerChanged);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Text(
                    '视频加载失败',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              else if (controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: Hero(
                      tag: widget.source.heroTag,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Text(
                        widget.source.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              if (_controlsVisible && controller != null && controller.value.isInitialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FullscreenVideoControlBar(
                    isPlaying: controller.value.isPlaying,
                    position: controller.value.position,
                    duration: controller.value.duration,
                    progressValue: controller.value.duration.inMilliseconds == 0
                        ? 0
                        : controller.value.position.inMilliseconds /
                            controller.value.duration.inMilliseconds,
                    onPlayPause: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                    },
                    onChanged: (_) {},
                    onChangeStart: (_) {},
                    onChangeEnd: (_) {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Re-run the fullscreen-page tests**

Run: `flutter test test/pages/fullscreen_video_player_page_test.dart -r expanded`

Expected: PASS for auto-play and tap-to-toggle controls.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/pages/fullscreen_video_player_page.dart \
  lib/widgets/fullscreen_video_control_bar.dart \
  test/pages/fullscreen_video_player_page_test.dart
git commit -m "feat: add fullscreen video player page shell"
```

## Task 4: Add seek logic, playback completion handling, auto-hide, and page-owned cleanup

**Files:**
- Modify: `lib/pages/fullscreen_video_player_page.dart`
- Modify: `test/pages/fullscreen_video_player_page_test.dart`

- [ ] **Step 1: Add the failing interaction tests**

Append these tests to `test/pages/fullscreen_video_player_page_test.dart`:

```dart
testWidgets('play button pauses and resumes playback', (tester) async {
  final fake = FakeVideoController();

  await tester.pumpWidget(
    MaterialApp(
      home: FullscreenVideoPlayerPage(
        source: const FullscreenVideoSource(
          filePath: '/tmp/demo.mp4',
          heroTag: 'vid-1',
        ),
        controllerFactory: (_) => fake,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.pause));
  await tester.pumpAndSettle();
  expect(fake.paused, isTrue);

  await tester.tap(find.byIcon(Icons.play_arrow));
  await tester.pumpAndSettle();
  expect(fake.played, isTrue);
});

testWidgets('seek resumes when the video was playing before drag',
    (tester) async {
  final fake = FakeVideoController();

  await tester.pumpWidget(
    MaterialApp(
      home: FullscreenVideoPlayerPage(
        source: const FullscreenVideoSource(
          filePath: '/tmp/demo.mp4',
          heroTag: 'vid-1',
        ),
        controllerFactory: (_) => fake,
      ),
    ),
  );
  await tester.pumpAndSettle();

  final state = tester.state<FullscreenVideoPlayerPageState>(
    find.byType(FullscreenVideoPlayerPage),
  );

  state.debugHandleSeekStart(0.2);
  state.debugHandleSeekChanged(0.5);
  await state.debugHandleSeekEnd(0.5);
  await tester.pumpAndSettle();

  expect(fake.value.position, const Duration(seconds: 14));
  expect(fake.value.isPlaying, isTrue);
});

testWidgets('seek stays paused when the video was paused before drag',
    (tester) async {
  final fake = FakeVideoController();

  await tester.pumpWidget(
    MaterialApp(
      home: FullscreenVideoPlayerPage(
        source: const FullscreenVideoSource(
          filePath: '/tmp/demo.mp4',
          heroTag: 'vid-1',
        ),
        controllerFactory: (_) => fake,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.pause));
  await tester.pumpAndSettle();

  final state = tester.state<FullscreenVideoPlayerPageState>(
    find.byType(FullscreenVideoPlayerPage),
  );

  state.debugHandleSeekStart(0.2);
  state.debugHandleSeekChanged(0.75);
  await state.debugHandleSeekEnd(0.75);
  await tester.pumpAndSettle();

  expect(fake.value.position, const Duration(seconds: 21));
  expect(fake.value.isPlaying, isFalse);
});

testWidgets('disposing the page disposes the controller', (tester) async {
  final fake = FakeVideoController();

  await tester.pumpWidget(
    MaterialApp(
      home: FullscreenVideoPlayerPage(
        source: const FullscreenVideoSource(
          filePath: '/tmp/demo.mp4',
          heroTag: 'vid-1',
        ),
        controllerFactory: (_) => fake,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pumpAndSettle();

  expect(fake.disposed, isTrue);
});
```

- [ ] **Step 2: Run the fullscreen-page tests and verify they fail**

Run: `flutter test test/pages/fullscreen_video_player_page_test.dart -r expanded`

Expected: FAIL because seek handlers, test hooks, and controller cleanup behavior are not fully implemented.

- [ ] **Step 3: Add seek state and debug-visible test hooks**

In `FullscreenVideoPlayerPageState`, add:

```dart
bool _wasPlayingBeforeSeek = false;
bool _isSeeking = false;
double? _dragValue;
Timer? _autoHideTimer;

@visibleForTesting
void debugHandleSeekStart(double value) => _handleSeekStart(value);

@visibleForTesting
void debugHandleSeekChanged(double value) => _handleSeekChanged(value);

@visibleForTesting
Future<void> debugHandleSeekEnd(double value) => _handleSeekEnd(value);

void _handleSeekStart(double value) {
  final controller = _controller;
  if (controller == null || !controller.value.isInitialized) return;
  _wasPlayingBeforeSeek = controller.value.isPlaying;
  _isSeeking = true;
  _dragValue = value;
  _cancelAutoHide();
}

void _handleSeekChanged(double value) {
  setState(() => _dragValue = value);
}

Future<void> _handleSeekEnd(double value) async {
  final controller = _controller;
  if (controller == null || !controller.value.isInitialized) return;
  final target = Duration(
    milliseconds: (controller.value.duration.inMilliseconds * value).round(),
  );
  await controller.seekTo(target);
  if (_wasPlayingBeforeSeek) {
    await controller.play();
  } else {
    await controller.pause();
  }
  setState(() {
    _isSeeking = false;
    _dragValue = null;
  });
  _scheduleAutoHide();
}
```

- [ ] **Step 4: Wire the seek bar, auto-hide timer, completion reset, and cleanup**

Add these helpers:

```dart
void _cancelAutoHide() {
  _autoHideTimer?.cancel();
  _autoHideTimer = null;
}

void _scheduleAutoHide() {
  final controller = _controller;
  if (controller == null || !controller.value.isPlaying || _isSeeking) return;
  _cancelAutoHide();
  _autoHideTimer = Timer(const Duration(seconds: 3), () {
    if (!mounted) return;
    setState(() => _controlsVisible = false);
  });
}

Future<void> _togglePlayPause() async {
  final controller = _controller;
  if (controller == null || !controller.value.isInitialized) return;
  final ended = controller.value.position >= controller.value.duration &&
      controller.value.duration > Duration.zero;
  if (ended) {
    await controller.seekTo(Duration.zero);
  }
  if (controller.value.isPlaying) {
    await controller.pause();
    _cancelAutoHide();
    setState(() => _controlsVisible = true);
  } else {
    await controller.play();
    setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }
}
```

Update the listener:

```dart
void _handleControllerChanged() {
  final controller = _controller;
  if (controller == null) return;
  final ended = controller.value.duration > Duration.zero &&
      controller.value.position >= controller.value.duration &&
      !controller.value.isPlaying;
  if (ended) {
    _cancelAutoHide();
    if (mounted) {
      setState(() => _controlsVisible = true);
    }
    return;
  }
  if (controller.value.isPlaying) {
    _scheduleAutoHide();
  }
  if (mounted) setState(() {});
}
```

Update the control bar call:

```dart
final duration = controller.value.duration;
final progressValue = _dragValue ??
    (duration.inMilliseconds == 0
        ? 0
        : controller.value.position.inMilliseconds / duration.inMilliseconds);
final displayPosition = _dragValue == null
    ? controller.value.position
    : Duration(
        milliseconds: (duration.inMilliseconds * _dragValue!).round(),
      );

FullscreenVideoControlBar(
  isPlaying: controller.value.isPlaying,
  position: displayPosition,
  duration: duration,
  progressValue: progressValue.clamp(0, 1),
  onPlayPause: _togglePlayPause,
  onChanged: _handleSeekChanged,
  onChangeStart: _handleSeekStart,
  onChangeEnd: (value) => unawaited(_handleSeekEnd(value)),
)
```

In `dispose()`, also add page-owned file cleanup:

```dart
_cancelAutoHide();
if (widget.source.ownsFile) {
  unawaited(File(widget.source.filePath).delete().catchError((_) {}));
}
```

- [ ] **Step 5: Re-run the fullscreen-page tests**

Run: `flutter test test/pages/fullscreen_video_player_page_test.dart -r expanded`

Expected: PASS for play / pause, seek-resume behavior, seek-stays-paused behavior, and controller disposal.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/pages/fullscreen_video_player_page.dart \
  test/pages/fullscreen_video_player_page_test.dart
git commit -m "feat: add fullscreen video playback controls"
```

## Task 5: Wire the bubble play button to fullscreen playback and run full verification

**Files:**
- Modify: `lib/widgets/event_media_content.dart`
- Modify: `test/widgets/chat_video_preview_card_test.dart`
- Modify: `test/widgets/fullscreen_video_player_route_test.dart`
- Modify: `test/pages/fullscreen_video_player_page_test.dart`

- [ ] **Step 1: Add a focused regression test for play-button-only entry**

Append this test to `test/widgets/chat_video_preview_card_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the focused tests to lock in the existing route and page behavior**

Run:

```bash
flutter test test/widgets/chat_video_preview_card_test.dart -r expanded
flutter test test/widgets/fullscreen_video_player_route_test.dart -r expanded
flutter test test/pages/fullscreen_video_player_page_test.dart -r expanded
```

Expected: PASS for the existing preview-card, route-helper, and fullscreen-page cases before the final `EventMediaContent` wiring step.

- [ ] **Step 3: Finalize the `EventMediaContent` video branch for route-based playback**

Make sure the video branch has all of these properties at once:

```dart
case MessageTypes.Video:
  final controller = _video;
  final path = _tempVideoPath;
  if (controller == null || !controller.value.isInitialized || path == null) {
    return Text(
      '[视频解码中…]',
      style: TextStyle(fontSize: 13, color: subtext),
    );
  }

  final aspectRatio =
      controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio;
  final duration = controller.value.duration;
  final heroTag = 'event-video-${widget.event.eventId}';

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: ChatVideoPreviewCard(
        duration: duration,
        onPlay: () {
          openFullscreenVideoPlayer(
            context,
            source: FullscreenVideoSource(
              filePath: path,
              heroTag: heroTag,
              durationHint: duration,
              ownsFile: false,
            ),
          );
        },
        child: Hero(
          tag: heroTag,
          child: VideoPlayer(controller),
        ),
      ),
    ),
  );
```

- [ ] **Step 4: Run full verification**

Run:

```bash
flutter analyze
flutter test --no-pub
```

Expected: `flutter analyze` reports no new issues, and the full suite passes.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/widgets/event_media_content.dart \
  test/widgets/chat_video_preview_card_test.dart \
  test/widgets/fullscreen_video_player_route_test.dart \
  test/pages/fullscreen_video_player_page_test.dart
git commit -m "feat: open chat videos in fullscreen player"
```

## Self-Review

### Spec coverage

- Preview-only bubble with play button and duration: covered by Task 2.
- Play-button-only entry into fullscreen: covered by Tasks 2 and 5.
- Fullscreen dark page with back, play / pause, seek bar, and time labels: covered by Tasks 3 and 4.
- Auto-play on entry: covered by Task 3.
- Seek resume / stay-paused rules: covered by Task 4.
- Resource cleanup on exit: covered by Task 4.
- Markdown video explicitly out of scope: preserved by limiting modifications to `EventMediaContent` only.

No spec gaps remain for the first implementation.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” steps remain in the plan.
- Each code-changing step includes concrete code.
- Each verification step includes exact commands and expected outcomes.

### Type consistency

- Shared source type stays `FullscreenVideoSource` across all tasks.
- Shared route helper stays `openFullscreenVideoPlayer(...)`.
- Fullscreen page stays `FullscreenVideoPlayerPage`.
- Preview card stays `ChatVideoPreviewCard`.
- Controller factory type stays `FullscreenVideoControllerFactory`.
