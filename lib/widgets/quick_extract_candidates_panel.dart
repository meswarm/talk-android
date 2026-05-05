import 'package:flutter/material.dart';

import '../quick_extract/quick_extract_models.dart';
import '../theme/app_colors.dart';

class QuickExtractCandidatesPanel extends StatelessWidget {
  const QuickExtractCandidatesPanel({
    super.key,
    required this.items,
    required this.onPick,
    this.maxHeight,
  });

  final List<QuickExtractCandidate> items;
  final ValueChanged<QuickExtractCandidate> onPick;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final maxPanelHeight =
        maxHeight ?? MediaQuery.of(context).size.height * 0.5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPanelHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_fix_high_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '快速提取',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${items.length} 项',
                        style: TextStyle(color: subtext, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Material(
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onPick(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (item.value != item.label) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.2,
                                            color: subtext,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.north_west_rounded,
                                  size: 18,
                                  color: subtext,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
