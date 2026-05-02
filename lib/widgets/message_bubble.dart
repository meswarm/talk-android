import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '../providers/bubble_max_height_provider.dart';
import '../theme/app_colors.dart';
import 'expandable_markdown_body.dart';
import 'markdown_renderer.dart';
import 'matrix_authenticated_image.dart';

const double _kAvatarSize = 36;
const double _kOtherAvatarSize = 24;
const double _kAvatarGap = 8;

/// 多行等普通文本气泡（略紧）。
const EdgeInsets _kBubblePaddingText = EdgeInsets.fromLTRB(10, 2, 10, 2);

class MessageBubble extends StatelessWidget {
  final Event event;
  final bool isOwnMessage;
  final Room room;
  final bool autoCollapseEnabled;

  const MessageBubble({
    super.key,
    required this.event,
    required this.isOwnMessage,
    required this.room,
    this.autoCollapseEnabled = true,
  });

  String _eventRenderKey() {
    if (event.eventId.isNotEmpty) return event.eventId;
    final txn = event.transactionId;
    if (txn != null && txn.isNotEmpty) return 'txn:$txn';
    return '${event.senderId}:${event.originServerTs.millisecondsSinceEpoch}:${event.body.hashCode}';
  }

  double _maxBubbleWidth(BuildContext context, {required bool isOwnMessage}) {
    final w = MediaQuery.sizeOf(context).width;
    const hPad = 20.0;
    if (isOwnMessage) {
      return min(w * 0.8, w - hPad - _kAvatarSize - _kAvatarGap);
    }
    return w - hPad;
  }

  Widget _wrapShrinkBubble(
    BuildContext context,
    Widget child, {
    required bool isOwnMessage,
    bool fillWidth = false,
  }) {
    final maxW = _maxBubbleWidth(context, isOwnMessage: isOwnMessage);
    if (fillWidth) {
      return SizedBox(width: maxW, child: child);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: child,
    );
  }

  BoxDecoration _bubbleDecoration(Color bubbleColor) {
    return BoxDecoration(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (event.type == EventTypes.Sticker) {
      return _buildStickerBubble(context, isDark);
    }

    if (event.type != EventTypes.Message) {
      return _buildSystemMessage(context, isDark);
    }

    final bubbleColor = isOwnMessage
        ? (isDark ? AppColors.darkMyBubble : AppColors.lightMyBubble)
        : (isDark ? AppColors.darkOtherBubble : AppColors.lightOtherBubble);

    final msgType = event.messageType;
    final isMedia =
        msgType == MessageTypes.Image ||
        msgType == MessageTypes.Video ||
        msgType == MessageTypes.Audio ||
        msgType == MessageTypes.File;

    final senderUser = room.unsafeGetUserFromMemoryOrFallback(event.senderId);

    final columnAlign = isOwnMessage
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final hasR2Link = event.body.contains('r2://');
    final eventRenderKey = _eventRenderKey();
    final isSingleLineCompact =
        !isMedia &&
        !hasR2Link &&
        !event.body.contains('\n') &&
        event.body.length < 40;
    final shouldFillOtherBubble =
        !isOwnMessage && !isMedia && !isSingleLineCompact;

    Widget bubble;

    if (isSingleLineCompact) {
      bubble = IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minHeight: _kAvatarSize),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: _bubbleDecoration(bubbleColor),
          child: Align(
            alignment: isOwnMessage
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: MarkdownRenderer(
              data: event.body,
              isDark: isDark,
              compactLineHeight: true,
            ),
          ),
        ),
      );
    } else {
      const pad = _kBubblePaddingText;
      final screenH = MediaQuery.sizeOf(context).height;
      final bubbleMaxH = context
          .watch<BubbleMaxHeightProvider>()
          .maxHeightForViewport(screenH);
      bubble = Container(
        padding: pad,
        decoration: _bubbleDecoration(bubbleColor),
        child: Column(
          crossAxisAlignment: columnAlign,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: isOwnMessage
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: isMedia
                  ? _MatrixNativeMediaUnsupported(isDark: isDark)
                  : ExpandableMarkdownBody(
                      key: ValueKey<String>('expandable:$eventRenderKey'),
                      data: event.body,
                      isDark: isDark,
                      isOwnMessage: isOwnMessage,
                      maxHeight: bubbleMaxH,
                      bubbleColor: bubbleColor,
                      autoCollapseEnabled: autoCollapseEnabled,
                    ),
            ),
          ],
        ),
      );
      // 长单行（无换行但未走等高分支）仍按内容收窄宽度。
      if (!isMedia && !event.body.contains('\n') && event.body.length >= 120) {
        bubble = IntrinsicWidth(child: bubble);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: _buildAvatarRow(
        isOwnMessage: isOwnMessage,
        senderUser: senderUser,
        bubble: _wrapShrinkBubble(
          context,
          bubble,
          isOwnMessage: isOwnMessage,
          fillWidth: shouldFillOtherBubble,
        ),
      ),
    );
  }

  Widget _buildAvatarRow({
    required bool isOwnMessage,
    required User senderUser,
    required Widget bubble,
  }) {
    final avatar = UserSquareAvatar(
      user: senderUser,
      size: isOwnMessage ? _kAvatarSize : _kOtherAvatarSize,
    );

    if (isOwnMessage) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          bubble,
          const SizedBox(width: _kAvatarGap),
          avatar,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: avatar,
        ),
        bubble,
      ],
    );
  }

  Widget _buildStickerBubble(BuildContext context, bool isDark) {
    final bubbleColor = isOwnMessage
        ? (isDark ? AppColors.darkMyBubble : AppColors.lightMyBubble)
        : (isDark ? AppColors.darkOtherBubble : AppColors.lightOtherBubble);

    final textColor = isOwnMessage
        ? (isDark ? AppColors.darkMyBubbleText : AppColors.lightMyBubbleText)
        : (isDark
              ? AppColors.darkOtherBubbleText
              : AppColors.lightOtherBubbleText);

    final senderUser = room.unsafeGetUserFromMemoryOrFallback(event.senderId);

    Widget bubble = Container(
      padding: _kBubblePaddingText,
      decoration: _bubbleDecoration(bubbleColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.hasAttachment)
            _MatrixNativeMediaUnsupported(isDark: isDark)
          else
            Align(
              alignment: Alignment.center,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: Text(
                event.body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, color: textColor),
              ),
            ),
        ],
      ),
    );

    bubble = IntrinsicWidth(child: bubble);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: _buildAvatarRow(
        isOwnMessage: isOwnMessage,
        senderUser: senderUser,
        bubble: _wrapShrinkBubble(
          context,
          bubble,
          isOwnMessage: isOwnMessage,
          fillWidth: !isOwnMessage,
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _getSystemMessageText(),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _getSystemMessageText() {
    if (event.type == EventTypes.RoomMember) {
      return '${event.senderFromMemoryOrFallback.displayName ?? event.senderId} 加入了房间';
    }
    return event.body;
  }
}

class _MatrixNativeMediaUnsupported extends StatelessWidget {
  const _MatrixNativeMediaUnsupported({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161);
    return Text(
      '[不支持 Matrix 原生媒体，请使用 R2 Markdown]',
      style: TextStyle(fontSize: 13, color: color),
    );
  }
}
