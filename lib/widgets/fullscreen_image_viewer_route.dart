import 'package:flutter/material.dart';

import '../media/fullscreen_image_source.dart';
import '../pages/fullscreen_image_viewer_page.dart';

Future<void> openFullscreenImageViewer(
  BuildContext context, {
  required FullscreenImageSource source,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => FullscreenImageViewerPage(source: source),
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}
