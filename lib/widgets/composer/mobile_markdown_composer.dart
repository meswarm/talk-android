import 'package:flutter/material.dart';

import '../../services/local_storage.dart';
import '../../theme/app_colors.dart';
import '../markdown_renderer.dart';
import 'markdown_composer_toolbar.dart';
import 'markdown_source_editor.dart';
import 'markdown_syntax_text_editing_controller.dart';

enum ComposerViewMode { source, preview }

/// Inset shadow along the inner edge of the markdown card (Flutter has no
/// built-in inner shadow; this uses subtle edge gradients).
class _MarkdownEditorInnerShadow extends StatelessWidget {
  const _MarkdownEditorInnerShadow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Narrow strips + lower alpha: subtle inset without eating content area.
    final edge = isDark ? 0.20 : 0.045;
    final side = isDark ? 0.14 : 0.032;
    const topH = 5.0;
    const bottomH = 5.0;
    const sideW = 4.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: topH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: edge),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: edge * 0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: sideW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: side),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: sideW,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.black.withValues(alpha: side),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerResizeHandle extends StatefulWidget {
  const _ComposerResizeHandle({
    required this.isDark,
    required this.panelHeight,
    required this.composerHeightPct,
    required this.onHeightPctChanged,
  });

  final bool isDark;
  final double panelHeight;
  final double composerHeightPct;
  final ValueChanged<double> onHeightPctChanged;

  @override
  State<_ComposerResizeHandle> createState() => _ComposerResizeHandleState();
}

class _ComposerResizeHandleState extends State<_ComposerResizeHandle> {
  double? _anchorY;
  double? _anchorPct;

  @override
  Widget build(BuildContext context) {
    final divider =
        widget.isDark ? AppColors.darkDivider : AppColors.lightDivider;
    return Semantics(
      label: '拖动调整输入区高度',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (d) {
          _anchorY = d.globalPosition.dy;
          _anchorPct = widget.composerHeightPct;
        },
        onVerticalDragUpdate: (d) {
          final anchorY = _anchorY;
          final anchorPct = _anchorPct;
          if (anchorY == null || anchorPct == null) return;
          final panelH = widget.panelHeight;
          if (panelH <= 0) return;
          final deltaPct =
              ((anchorY - d.globalPosition.dy) / panelH) * 100.0;
          final next = (anchorPct + deltaPct).clamp(
            LocalStorage.minComposerHeightPct.toDouble(),
            LocalStorage.maxComposerHeightPct.toDouble(),
          );
          widget.onHeightPctChanged(next);
        },
        onVerticalDragEnd: (_) {
          _anchorY = null;
          _anchorPct = null;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: Container(
            height: 6,
            color: divider.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

/// Expanded mobile composer: toolbar, source or preview, resize handle.
/// Sending is done from the collapsed composer only (avoids accidental send).
class MobileMarkdownComposer extends StatelessWidget {
  const MobileMarkdownComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.panelHeight,
    required this.composerHeightPct,
    required this.viewMode,
    required this.onTogglePreview,
    required this.uploadingMedia,
    required this.onChanged,
    required this.onInsertCode,
    required this.onPickMediaLibrary,
    required this.onOpenCameraCapture,
    required this.onInsertFile,
    required this.onClearAll,
    required this.onCollapse,
    required this.onHeightPctChanged,
  });

  final MarkdownSyntaxTextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final double panelHeight;
  final double composerHeightPct;
  final ComposerViewMode viewMode;
  final VoidCallback onTogglePreview;
  final bool uploadingMedia;
  final ValueChanged<String> onChanged;
  final VoidCallback onInsertCode;
  final VoidCallback onPickMediaLibrary;
  final VoidCallback onOpenCameraCapture;
  final VoidCallback onInsertFile;
  final VoidCallback onClearAll;
  final VoidCallback onCollapse;
  final ValueChanged<double> onHeightPctChanged;

  @override
  Widget build(BuildContext context) {
    final pct = composerHeightPct.clamp(
      LocalStorage.minComposerHeightPct.toDouble(),
      LocalStorage.maxComposerHeightPct.toDouble(),
    );
    final height = panelHeight * (pct / 100.0);
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final previewing = viewMode == ComposerViewMode.preview;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ComposerResizeHandle(
            isDark: isDark,
            panelHeight: panelHeight,
            composerHeightPct: pct,
            onHeightPctChanged: onHeightPctChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: MarkdownComposerToolbar(
              enabled: !uploadingMedia,
              previewing: previewing,
              composerText: controller,
              onTogglePreview: onTogglePreview,
              onInsertCode: onInsertCode,
              onPickMediaLibrary: onPickMediaLibrary,
              onOpenCameraCapture: onOpenCameraCapture,
              onInsertFile: onInsertFile,
              onClearAll: onClearAll,
              onCollapse: onCollapse,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: divider, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground,
                      ),
                      if (uploadingMedia)
                        Center(
                          child: Text(
                            '上传中…',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                              fontSize: 15,
                            ),
                          ),
                        )
                      else if (previewing)
                        Positioned.fill(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            child: ListenableBuilder(
                              listenable: controller,
                              builder: (context, _) {
                                return MarkdownRenderer(
                                  data: controller.text,
                                  isDark: isDark,
                                  onDeleteMediaMarkdown: (nextText) {
                                    final oldOffset = controller.selection.baseOffset;
                                    final nextOffset = oldOffset >= 0
                                        ? oldOffset.clamp(0, nextText.length)
                                        : nextText.length;
                                    controller.value = TextEditingValue(
                                      text: nextText,
                                      selection: TextSelection.collapsed(
                                        offset: nextOffset,
                                      ),
                                    );
                                    onChanged(nextText);
                                  },
                                );
                              },
                            ),
                          ),
                        )
                      else
                        MarkdownSourceEditor(
                          controller: controller,
                          focusNode: focusNode,
                          isDark: isDark,
                          bottomInset: 0,
                          rightInset: 0,
                          readOnly: false,
                          onChanged: onChanged,
                        ),
                      _MarkdownEditorInnerShadow(isDark: isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
