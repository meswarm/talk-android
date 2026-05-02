import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../r2/r2_ref.dart';
import '../r2/r2_service.dart';
import '../theme/app_colors.dart';
import 'markdown_image_frame.dart';
import 'r2_markdown_card_shell.dart';

class R2MarkdownFileCard extends StatefulWidget {
  const R2MarkdownFileCard({
    super.key,
    required this.r2,
    required this.ref,
    required this.title,
    required this.isDark,
    this.maxImageHeight = 220,
    this.cardHeight,
    this.maxImageWidth,
    this.onDelete,
  });

  final R2Service r2;
  final String ref;
  final String title;
  final bool isDark;
  final double maxImageHeight;
  final double? cardHeight;
  final double? maxImageWidth;
  final VoidCallback? onDelete;

  @override
  State<R2MarkdownFileCard> createState() => _R2MarkdownFileCardState();
}

class _R2MarkdownFileCardState extends State<R2MarkdownFileCard> {
  bool _opening = false;
  String? _error;

  String get _displayTitle {
    final t = widget.title.trim();
    if (t.isNotEmpty) return t;
    final parsed = parseR2Ref(widget.ref);
    if (parsed == null) return '文件';
    return p.basename(parsed.objectKey);
  }

  IconData get _icon {
    final ext = p.extension(_displayTitle).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
      case '.docx':
      case '.txt':
        return Icons.description_outlined;
      case '.xls':
      case '.xlsx':
      case '.csv':
        return Icons.table_chart_outlined;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow_outlined;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _openExternal() async {
    if (_opening) return;
    if (widget.r2.session == null) {
      setState(() => _error = '解锁 R2 后可打开此文件');
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final bytes = await widget.r2.fetchRefBytes(widget.ref);
      final dir = await getTemporaryDirectory();
      final parsed = parseR2Ref(widget.ref);
      final fallbackName = parsed == null
          ? _displayTitle
          : p.basename(parsed.objectKey);
      final safeName = sanitizeFilenameForKey(fallbackName);
      final file = File(
        p.join(
          dir.path,
          'talk_r2_${DateTime.now().microsecondsSinceEpoch}_$safeName',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        setState(() => _opening = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _opening = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.isDark
        ? const Color(0xFF9E9E9E)
        : const Color(0xFF616161);
    final titleColor = widget.isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF111111);
    final cardHeight = (widget.cardHeight ?? 64).clamp(36.0, 120.0);
    final compact = cardHeight <= 48;
    final verticalPad = compact ? 4.0 : 10.0;
    final iconBox = (cardHeight - verticalPad * 2).clamp(28.0, 36.0);
    final iconSize = iconBox.clamp(20.0, 24.0);
    final titleFont = compact ? 12.0 : 13.0;
    final subtitleFont = compact ? 10.5 : 12.0;
    final cardWidth = widget.maxImageWidth?.clamp(96.0, 420.0).toDouble();
    final card = MarkdownImageFrame(
      isDark: widget.isDark,
      maxHeight: cardHeight,
      maxWidth: widget.maxImageWidth ?? double.infinity,
      child: Material(
        color: widget.isDark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF3F4F6),
        child: InkWell(
          onTap: _opening ? null : () => unawaited(_openExternal()),
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: verticalPad,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: iconBox,
                    height: iconBox,
                    child: Center(
                      child: _opening
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.isDark
                                    ? Colors.white54
                                    : AppColors.primary,
                              ),
                            )
                          : Icon(
                              _icon,
                              size: iconSize,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleFont,
                            height: 1.2,
                            color: titleColor,
                          ),
                        ),
                        SizedBox(height: compact ? 1 : 4),
                        Text(
                          _error ?? '点击在其他应用中打开',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: subtitleFont,
                            height: 1.2,
                            color: _error == null ? sub : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return R2MarkdownCardShell(onDelete: widget.onDelete, child: card);
  }
}
