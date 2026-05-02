import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded frame + border for markdown images; content is [Align]ed left.
class MarkdownImageFrame extends StatelessWidget {
  const MarkdownImageFrame({
    super.key,
    required this.isDark,
    required this.maxHeight,
    required this.maxWidth,
    required this.child,
  });

  final bool isDark;
  final double maxHeight;
  final double maxWidth;
  final Widget child;

  static const double radius = 8;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    // Full-width row + left align so markdown blocks that center children
    // still flush images to the start edge.
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 1),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
                maxWidth: maxWidth,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
