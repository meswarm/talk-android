import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';

/// 相邻两条消息时间差达到该值时，在较新的一条上方显示分隔（大致时间）。
const Duration kChatTimeSeparatorGap = Duration(minutes: 30);

/// 居中灰色胶囊，显示「上一次」消息的大致时间。
class ChatTimeSeparator extends StatelessWidget {
  final DateTime referenceTime;

  const ChatTimeSeparator({
    super.key,
    required this.referenceTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final label = formatChatTimeSeparatorLabel(referenceTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: sub,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 以「间隔前一条（较旧）消息」的时间为参考，输出简短中文标签。
String formatChatTimeSeparatorLabel(DateTime ts) {
  final d = ts.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final daysDiff = today.difference(day).inDays;

  final hm = DateFormat('HH:mm').format(d);

  if (daysDiff == 0) {
    return hm;
  }
  if (daysDiff == 1) {
    return '昨天 $hm';
  }
  if (d.year == now.year) {
    return '${d.month}月${d.day}日 $hm';
  }
  return DateFormat('yyyy-MM-dd $hm').format(d);
}
