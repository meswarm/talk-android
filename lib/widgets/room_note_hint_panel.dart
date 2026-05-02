import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 聊天页顶部只读「房间提示」卡片；内容由房间信息页编辑并持久化。
/// 仅展示正文，无标题栏；全宽、左对齐、轻阴影。
class RoomNoteHintPanel extends StatelessWidget {
  const RoomNoteHintPanel({
    super.key,
    required this.isDark,
    required this.text,
  });

  final bool isDark;
  final String text;

  static const double _fontEmpty = 12;
  static const double _fontBody = 12.5;

  @override
  Widget build(BuildContext context) {
    final sub =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final bodyColor =
        isDark ? AppColors.darkAppBarText : AppColors.lightAppBarText;

    final bg = isDark
        ? AppColors.darkRoomNoteHintPanel
        : AppColors.lightRoomNoteHintPanel;

    final borderColor = isDark
        ? AppColors.primary.withValues(alpha: 0.42)
        : AppColors.primary.withValues(alpha: 0.38);

    final shadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];

    final body = text.trim().isEmpty
        ? Text(
            '尚未设置提示内容。可在「房间信息」中编辑「房间提示」。',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: _fontEmpty,
              height: 1.35,
              color: sub,
            ),
          )
        : SelectableText(
            text,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: _fontBody,
              height: 1.38,
              color: bodyColor,
            ),
          );

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: shadows,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
