import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Hides the Material/Cupertino selection drag handles (teardrop / ball) so the
/// user only sees the blinking caret ([cursorWidth] on [TextField]).
class ComposerMaterialTextSelectionControls extends MaterialTextSelectionControls {
  @override
  Size getHandleSize(double textLineHeight) => Size.zero;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    return const SizedBox.shrink();
  }
}

/// Same as [ComposerMaterialTextSelectionControls] for iOS-style controls.
class ComposerCupertinoTextSelectionControls
    extends CupertinoTextSelectionControls {
  @override
  Size getHandleSize(double textLineHeight) => Size.zero;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return const SizedBox.shrink();
  }
}

/// Picks platform-appropriate controls (matches typical [TextField] behavior).
TextSelectionControls composerTextSelectionControlsFor(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
      return ComposerCupertinoTextSelectionControls();
    default:
      return ComposerMaterialTextSelectionControls();
  }
}
