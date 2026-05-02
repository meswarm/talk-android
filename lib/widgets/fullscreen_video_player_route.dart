import 'package:flutter/material.dart';

import '../media/fullscreen_video_source.dart';
import '../pages/fullscreen_video_player_page.dart';

Future<void> openFullscreenVideoPlayer(
  BuildContext context, {
  required FullscreenVideoSource source,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => FullscreenVideoPlayerPage(source: source),
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}
