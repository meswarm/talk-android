import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'realtime_secretary_service.dart';

class RealtimeSecretaryDebugPanel extends StatelessWidget {
  const RealtimeSecretaryDebugPanel({
    super.key,
    required this.state,
    required this.entries,
  });

  final RealtimeSecretarySessionState state;
  final List<RealtimeSecretaryDebugEntry> entries;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final border = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(8),
      color: surface,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '实时语音秘书',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _stateLabel(state),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Flexible(
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '等待秘书活动',
                          style: TextStyle(color: subtext, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == entries.length - 1 ? 0 : 8,
                          ),
                          child: _DebugBubble(entry: entry, isDark: isDark),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(RealtimeSecretarySessionState state) {
    switch (state) {
      case RealtimeSecretarySessionState.announcing:
      case RealtimeSecretarySessionState.waitingWake:
        return '等待暗号';
      case RealtimeSecretarySessionState.activeChat:
        return '对话中';
      case RealtimeSecretarySessionState.closing:
        return '结束中';
      case RealtimeSecretarySessionState.idle:
        return '空闲';
    }
  }
}

class _DebugBubble extends StatelessWidget {
  const _DebugBubble({required this.entry, required this.isDark});

  final RealtimeSecretaryDebugEntry entry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.speaker == RealtimeSecretaryDebugSpeaker.user;
    final color = switch (entry.speaker) {
      RealtimeSecretaryDebugSpeaker.secretary => AppColors.primary.withValues(
        alpha: isDark ? 0.22 : 0.12,
      ),
      RealtimeSecretaryDebugSpeaker.user =>
        isDark ? AppColors.darkOtherBubble : const Color(0xFFF2F2F2),
      RealtimeSecretaryDebugSpeaker.system =>
        isDark
            ? AppColors.darkRoomNoteHintPanel
            : AppColors.lightRoomNoteHintPanel,
    };
    final textColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    final labelColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _speakerLabel(entry.speaker),
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _speakerLabel(RealtimeSecretaryDebugSpeaker speaker) {
    switch (speaker) {
      case RealtimeSecretaryDebugSpeaker.secretary:
        return '秘书';
      case RealtimeSecretaryDebugSpeaker.user:
        return '你';
      case RealtimeSecretaryDebugSpeaker.system:
        return '系统';
    }
  }
}
