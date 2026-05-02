import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/media_preview_sizes.dart';
import '../providers/media_preview_size_provider.dart';
import '../r2/r2_ref.dart';
import '../r2/r2_service.dart';
import 'package:talk/media/fullscreen_image_source.dart';
import 'package:talk/widgets/fullscreen_image_viewer_route.dart';
import 'markdown_image_frame.dart';
import 'markdown_selection_menu.dart';
import 'r2_markdown_audio.dart';
import 'r2_markdown_file_card.dart';
import 'r2_markdown_image.dart';
import 'r2_markdown_token.dart';
import 'r2_markdown_video.dart';

const EdgeInsets _kMarkdownTableCellPadding = EdgeInsets.fromLTRB(4, 4, 4, 4);
const double _kMarkdownTableTrailingScrollGutter = 14.0;

/// GFM 表格分隔行：`| --- | --- |`（每格为 `-` / `:`，至少 3 个 `-`）。
bool _isMarkdownTableSeparatorLine(String line) {
  final t = line.trim();
  if (!t.startsWith('|') || !t.endsWith('|')) return false;
  final parts = t.split('|');
  if (parts.length < 3) return false;
  for (var i = 1; i < parts.length - 1; i++) {
    final s = parts[i].trim();
    if (s.isEmpty) return false;
    if (!RegExp(r'^:?-{3,}:?$').hasMatch(s)) return false;
  }
  return true;
}

/// 从 `| a | b |` 行解析列数（不含两侧竖线产生的空段）。
int? _countMarkdownTableColumns(String line) {
  final t = line.trim();
  if (!t.startsWith('|') || !t.endsWith('|')) return null;
  final parts = t.split('|');
  if (parts.length < 3) return null;
  return parts.length - 2;
}

/// 第一个非分隔行的表头/表体行的列数。
int? _firstMarkdownTableColumnCount(String data) {
  for (final line in data.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('|')) continue;
    if (_isMarkdownTableSeparatorLine(t)) continue;
    return _countMarkdownTableColumns(t);
  }
  return null;
}

int _markdownTableSeparatorLineCount(String data) {
  var n = 0;
  for (final line in data.split('\n')) {
    if (_isMarkdownTableSeparatorLine(line)) n++;
  }
  return n;
}

/// 单列宽：所有列都先按内容计算理想宽度，同时都参与剩余空间分配与超宽压缩。
///
/// 仅当全文只有 **一个** GFM 表格（恰好一条 `|---|` 分隔行）时启用，否则多表共用同一
/// [columnWidths] 会错位；多表时退回纯 intrinsic，由表格外 [maxWidth] 约束换行。
Map<int, TableColumnWidth>? _markdownTableColumnWidths(
  BuildContext context,
  String data,
) {
  if (_markdownTableSeparatorLineCount(data) != 1) return null;
  final n = _firstMarkdownTableColumnCount(data);
  if (n == null || n <= 1) return null;
  final viewportWidth = MediaQuery.sizeOf(context).width;
  final maxColumnWidth = (viewportWidth * 0.84).clamp(240.0, 440.0);
  return {
    for (var i = 0; i < n; i++)
      i: MinColumnWidth(
        const MaxColumnWidth(IntrinsicColumnWidth(), FlexColumnWidth()),
        FixedColumnWidth(maxColumnWidth),
      ),
  };
}

/// 宽表格：横向滚动；内容按自然宽度布局，但至少撑满可用宽度。
Widget _wrapMarkdownTableForNarrowScreen(
  BuildContext context,
  BoxConstraints constraints,
  Widget table,
) {
  var minW = 0.0;
  if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
    minW = constraints.maxWidth;
  } else {
    minW = MediaQuery.sizeOf(context).width;
  }

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: minW),
          child: table,
        ),
        const SizedBox(width: _kMarkdownTableTrailingScrollGutter),
      ],
    ),
  );
}

Future<void> markdownOpenLink(BuildContext context, String url) async {
  final parsed = parseR2Ref(url);
  if (parsed != null) {
    final r2 = Provider.of<R2Service>(context, listen: false);
    if (r2.session == null) return;
    try {
      final u = await r2.presignedGetUri(url);
      if (context.mounted) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class MarkdownRenderer extends StatelessWidget {
  final String data;
  final bool isDark;

  /// 为 false 时不包 [SelectionArea]，便于聊天气泡按内容收缩宽度。
  final bool selectable;

  /// 单行聊天气泡：收紧行高并均匀分配上下 leading，避免「上宽下窄」。
  final bool compactLineHeight;

  /// Caps rendered markdown images (`r2://`, `http(s)`, asset). Chat bubbles use defaults.
  final double maxImageHeight;
  final double? maxImageWidth;
  final ValueChanged<String>? onDeleteMediaMarkdown;

  const MarkdownRenderer({
    super.key,
    required this.data,
    required this.isDark,
    this.selectable = true,
    this.compactLineHeight = false,
    this.maxImageHeight = 220,
    this.maxImageWidth,
    this.onDeleteMediaMarkdown,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final md = rewriteR2BracketLinksToPreviewCardsMarkdown(data);
    final sourceTokens = parseR2MarkdownTokens(data);
    final previewTokens = parseR2MarkdownTokens(md);
    var previewTokenIndex = 0;
    final r2 = context.watch<R2Service>();
    final mediaSizeProvider = context.watch<MediaPreviewSizeProvider?>();
    MediaPreviewSizes mediaSizesForToken(int sourceTokenIndex) {
      if (mediaSizeProvider == null || sourceTokenIndex < 0) {
        return MediaPreviewSizes.bubbleDefaults;
      }
      if (sourceTokenIndex >= sourceTokens.length) {
        return mediaSizeProvider.bubbleSizes;
      }
      final sourceToken = sourceTokens[sourceTokenIndex];
      final previewContext = markdownMediaPreviewContextForOffset(
        data,
        sourceToken.start,
      );
      return mediaSizeProvider.sizesFor(previewContext);
    }

    double mediaPreviewWidth(int width) {
      final configured = width.toDouble();
      if (maxImageWidth == null) return configured;
      return configured.clamp(0.0, maxImageWidth!).toDouble();
    }

    final config = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;

    final paragraphStyle = TextStyle(
      fontSize: 15,
      height: compactLineHeight ? 1.05 : 1.5,
      leadingDistribution: compactLineHeight
          ? TextLeadingDistribution.even
          : TextLeadingDistribution.proportional,
      color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF111111),
    );
    final headingColor = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF111111);

    final block = MarkdownBlock(
      data: md,
      selectable: false,
      config: config.copy(
        configs: [
          // 聊天气泡内标题：默认 32/24/20 过大，收窄为 20/18/16（正文 15）
          H1Config(
            style: TextStyle(
              fontSize: 20,
              height: 26 / 20,
              fontWeight: FontWeight.bold,
              color: headingColor,
            ),
          ),
          H2Config(
            style: TextStyle(
              fontSize: 18,
              height: 22 / 18,
              fontWeight: FontWeight.bold,
              color: headingColor,
            ),
          ),
          H3Config(
            style: TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.bold,
              color: headingColor,
            ),
          ),
          // 代码块配置
          isDark
              ? PreConfig.darkConfig.copy(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : const PreConfig().copy(
                  decoration: BoxDecoration(
                    color: Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
          // 行内代码配置
          CodeConfig(
            style: TextStyle(
              backgroundColor: isDark
                  ? const Color(0xFF2D2D2D)
                  : const Color(0xFFEFF1F3),
              color: isDark ? const Color(0xFFCE9178) : const Color(0xFFC7254E),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          // 段落配置
          PConfig(textStyle: paragraphStyle),
          // 链接配置（含 r2:// 预签名打开）
          LinkConfig(
            style: TextStyle(
              color: isDark ? const Color(0xFF6CB6FF) : const Color(0xFF0969DA),
              decoration: TextDecoration.underline,
            ),
            onTap: (url) => unawaited(markdownOpenLink(context, url)),
          ),
          TableConfig(
            columnWidths: _markdownTableColumnWidths(context, md),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            headPadding: _kMarkdownTableCellPadding,
            bodyPadding: _kMarkdownTableCellPadding,
            wrapper: (table) => LayoutBuilder(
              builder: (context, constraints) =>
                  _wrapMarkdownTableForNarrowScreen(
                    context,
                    constraints,
                    table,
                  ),
            ),
          ),
          ImgConfig(
            builder: (url, attributes) {
              final imgMaxW = maxImageWidth ?? double.infinity;
              final r2Parsed = parseR2Ref(url);
              if (r2Parsed != null) {
                final tokenIndex = previewTokenIndex < previewTokens.length
                    ? previewTokenIndex++
                    : -1;
                final mediaSizes = mediaSizesForToken(tokenIndex);
                final deleteCallback =
                    onDeleteMediaMarkdown == null || tokenIndex < 0
                    ? null
                    : () {
                        if (tokenIndex >= sourceTokens.length) return;
                        final token = sourceTokens[tokenIndex];
                        onDeleteMediaMarkdown!(
                          data.replaceRange(token.start, token.end, ''),
                        );
                      };
                switch (inferR2MediaKind(url)) {
                  case R2MediaKind.video:
                    return R2MarkdownVideo(
                      r2: r2,
                      ref: url,
                      isDark: isDark,
                      maxImageHeight: mediaSizes.videoHeight.toDouble(),
                      maxImageWidth: mediaPreviewWidth(mediaSizes.videoWidth),
                      onDelete: deleteCallback,
                    );
                  case R2MediaKind.image:
                    return R2MarkdownImage(
                      r2: r2,
                      ref: url,
                      isDark: isDark,
                      maxImageHeight: mediaSizes.imageHeight.toDouble(),
                      maxImageWidth: mediaPreviewWidth(mediaSizes.imageWidth),
                      onDelete: deleteCallback,
                    );
                  case R2MediaKind.audio:
                    return R2MarkdownAudio(
                      r2: r2,
                      ref: url,
                      title: attributes['alt'] ?? '',
                      isDark: isDark,
                      maxImageHeight: mediaSizes.audioHeight.toDouble(),
                      cardHeight: mediaSizes.audioHeight.toDouble(),
                      maxImageWidth: mediaPreviewWidth(mediaSizes.audioWidth),
                      onDelete: deleteCallback,
                    );
                  default:
                    return R2MarkdownFileCard(
                      r2: r2,
                      ref: url,
                      title: attributes['alt'] ?? '',
                      isDark: isDark,
                      maxImageHeight: mediaSizes.fileHeight.toDouble(),
                      cardHeight: mediaSizes.fileHeight.toDouble(),
                      maxImageWidth: mediaPreviewWidth(mediaSizes.fileWidth),
                      onDelete: deleteCallback,
                    );
                }
              }
              double? width;
              double? height;
              if (attributes['width'] != null) {
                width = double.tryParse(attributes['width']!);
              }
              if (attributes['height'] != null) {
                height = double.tryParse(attributes['height']!);
              }
              final alt = attributes['alt'] ?? '';
              final isNetImage = url.startsWith('http');
              if (isNetImage) {
                final heroTag = 'markdown-network-$url';
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    openFullscreenImageViewer(
                      context,
                      source: FullscreenImageSource.network(
                        url: url,
                        heroTag: heroTag,
                      ),
                    );
                  },
                  child: Hero(
                    tag: heroTag,
                    child: MarkdownImageFrame(
                      isDark: isDark,
                      maxHeight: maxImageHeight,
                      maxWidth: imgMaxW,
                      child: Image.network(
                        url,
                        width: width,
                        height: height,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (_, _, _) => Text(
                          '[图片加载失败] $alt',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF9E9E9E)
                                : const Color(0xFF616161),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final heroTag = 'markdown-asset-$url';
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  openFullscreenImageViewer(
                    context,
                    source: FullscreenImageSource.asset(
                      assetName: url,
                      heroTag: heroTag,
                    ),
                  );
                },
                child: Hero(
                  tag: heroTag,
                  child: MarkdownImageFrame(
                    isDark: isDark,
                    maxHeight: maxImageHeight,
                    maxWidth: imgMaxW,
                    child: Image.asset(
                      url,
                      width: width,
                      height: height,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, _, _) => Text(
                        '[图片加载失败] $alt',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFF616161),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    return selectable
        ? MarkdownSelectionArea(sourceMarkdown: data, child: block)
        : block;
  }
}
