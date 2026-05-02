import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/media/fullscreen_video_source.dart';
import 'package:talk/pages/fullscreen_video_player_page.dart';
import 'package:video_player/video_player.dart';

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
  int playerId = VideoPlayerController.kUninitializedPlayerId;

  @override
  String get dataSource => '/tmp/demo.mp4';

  @override
  DataSourceType get dataSourceType => DataSourceType.file;

  @override
  Map<String, String> get httpHeaders => const {};

  @override
  String? get package => null;

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
    value = value.copyWith(
      position: moment,
      duration: const Duration(seconds: 28),
    );
  }

  @override
  Future<Duration?> get position async => value.position;

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
  Future<ClosedCaptionFile>? get closedCaptionFile => null;

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

    await tester.tap(find.byKey(kFullscreenVideoPlayerTapLayerKey));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

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
}
