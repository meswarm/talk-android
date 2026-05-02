import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import 'matrix_authenticated_image.dart';

double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0);

/// 会话列表头像边长（与 [MediaQuery.textScaler] 联动，避免大字时行高不足）。
double conversationListAvatarSize(BuildContext context) {
  final sf = _textScale(context);
  return (52.0 * sf).clamp(46.0, 68.0);
}

/// [ConversationTile] 水平内边距（与字体缩放一致）。
double conversationListTileHorizontalPadding(BuildContext context) {
  final sf = _textScale(context);
  return (16.0 * sf).clamp(14.0, 28.0);
}

/// 头像与标题列之间的间距（与字体缩放一致）。
double conversationListTileAvatarGap(BuildContext context) {
  final sf = _textScale(context);
  return (12.0 * sf).clamp(10.0, 22.0);
}

/// 与 [ConversationTile] 左侧留白对齐的分隔线 indent（标题文字起始位置）。
double conversationListDividerIndent(BuildContext context) {
  return conversationListTileHorizontalPadding(context) +
      conversationListAvatarSize(context) +
      conversationListTileAvatarGap(context);
}

/// [_InviteRow] 水平内边距（与字体缩放一致）。
double inviteRowHorizontalPadding(BuildContext context) {
  final sf = _textScale(context);
  return (12.0 * sf).clamp(10.0, 24.0);
}

/// 与 [_InviteRow] 左侧留白对齐的分隔线 indent。
double inviteRowDividerIndent(BuildContext context) {
  return inviteRowHorizontalPadding(context) +
      conversationListAvatarSize(context) +
      conversationListTileAvatarGap(context);
}

/// 搜索结果行顶部小头像边长（原 28dp，随字号缩放）。
double searchResultAvatarSize(BuildContext context) {
  final sf = _textScale(context);
  return (28.0 * sf).clamp(24.0, 42.0);
}

/// 搜索行头像与标题间距（原 8dp）。
double searchResultAvatarGap(BuildContext context) {
  final sf = _textScale(context);
  return (8.0 * sf).clamp(6.0, 14.0);
}

/// 与搜索行标题文字起始对齐的分隔线 indent。
double searchResultDividerIndent(BuildContext context) {
  return conversationListTileHorizontalPadding(context) +
      searchResultAvatarSize(context) +
      searchResultAvatarGap(context);
}

class ConversationTile extends StatelessWidget {
  final Room room;
  final String displayName;
  final String lastMessage;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  /// 置顶：左侧主色条 + 淡色底，便于与未置顶会话区分。
  final bool isPinned;

  const ConversationTile({
    super.key,
    required this.room,
    required this.displayName,
    required this.lastMessage,
    required this.onTap,
    this.onLongPress,
    this.isPinned = false,
  });

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return DateFormat('MM/dd').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = room.notificationCount;
    final lastEventTime = room.lastEvent?.originServerTs;
    final sf = _textScale(context);
    final avatarSize = conversationListAvatarSize(context);
    final hPad = conversationListTileHorizontalPadding(context);
    // 行高明显高于头像，上下留白更舒适。
    final vPad = (9.0 * sf).clamp(7.0, 18.0);
    final gap = conversationListTileAvatarGap(context);
    final titlePreviewGap = (4.0 * sf).clamp(3.0, 10.0);
    final inlineGap = (8.0 * sf).clamp(6.0, 16.0);
    final badgeH = (7.0 * sf).clamp(5.0, 12.0);
    final badgeV = (3.0 * sf).clamp(2.0, 8.0);

    final pinnedBg = isDark
        ? AppColors.primary.withValues(alpha: 0.14)
        : AppColors.primary.withValues(alpha: 0.06);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPinned ? pinnedBg : null,
          border: isPinned
              ? Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                )
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RoomSquareAvatar(
              room: room,
              size: avatarSize,
            ),
            SizedBox(width: gap),

            // 名称 + 最新消息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.28,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isDark
                                ? AppColors.darkAppBarText
                                : AppColors.lightAppBarText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: inlineGap),
                      Text(
                        _formatTime(lastEventTime),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: unreadCount > 0
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: titlePreviewGap),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        SizedBox(width: inlineGap),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: badgeH, vertical: badgeV),
                          decoration: BoxDecoration(
                            color: AppColors.unreadBadge,
                            borderRadius: BorderRadius.circular(10 * sf),
                          ),
                          child: Text(
                            unreadCount > 99
                                ? '99+'
                                : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
