import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import 'markdown_renderer.dart';

double _fadeGradientHeight(double maxHeight) {
  return (maxHeight * 0.62).clamp(44.0, 96.0);
}

/// 在 [maxHeight] 内收起长 Markdown；溢出时底部渐变 + 居中横杠（触控区加大）。
class ExpandableMarkdownBody extends StatefulWidget {
  const ExpandableMarkdownBody({
    super.key,
    required this.data,
    required this.isDark,
    required this.isOwnMessage,
    required this.maxHeight,
    required this.bubbleColor,
    this.autoCollapseEnabled = true,
  });

  final String data;
  final bool isDark;
  final bool isOwnMessage;
  final double maxHeight;

  /// 与气泡背景一致，用于底部透明 → 实色的渐变。
  final Color bubbleColor;

  /// 为 `false` 时完整展示 Markdown，不进行高度裁剪与展开条。
  final bool autoCollapseEnabled;

  @override
  State<ExpandableMarkdownBody> createState() => _ExpandableMarkdownBodyState();
}

class _ExpandableMarkdownBodyState extends State<ExpandableMarkdownBody> {
  bool _expanded = false;
  bool _overflow = false;

  @override
  void didUpdateWidget(ExpandableMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _expanded = false;
      _overflow = false;
      return;
    }
    if (oldWidget.autoCollapseEnabled && !widget.autoCollapseEnabled) {
      _expanded = false;
      _overflow = false;
    }
  }

  Widget _barToggle({required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
            child: Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (!_expanded) {
        _overflow = true;
      }
    });
  }

  void _onOverflowChanged(bool overflow) {
    if (overflow != _overflow && mounted && !_expanded) {
      setState(() => _overflow = overflow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markdown = MarkdownRenderer(data: widget.data, isDark: widget.isDark);

    if (!widget.autoCollapseEnabled) {
      return Column(
        crossAxisAlignment: widget.isOwnMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [markdown],
      );
    }

    final showToggle = _expanded || _overflow;

    return Column(
      crossAxisAlignment: widget.isOwnMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_expanded)
          Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              _ClippedOverflowBox(
                maxHeight: widget.maxHeight,
                onOverflowChanged: _onOverflowChanged,
                child: markdown,
              ),
              if (_overflow) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _fadeGradientHeight(widget.maxHeight),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.bubbleColor.withValues(alpha: 0),
                            widget.bubbleColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(child: _barToggle(tooltip: '展开')),
                ),
              ],
            ],
          )
        else
          markdown,
        if (showToggle && _expanded)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Center(child: _barToggle(tooltip: '折叠')),
          ),
      ],
    );
  }
}

/// Lays out [child] with unbounded height, clips to [maxHeight] when the child
/// exceeds it, and reports overflow state changes via [onOverflowChanged].
///
/// Unlike [SingleChildScrollView], this does NOT create a nested [Scrollable],
/// avoiding gesture conflicts with an outer scrollable (e.g. a chat [ListView]).
class _ClippedOverflowBox extends SingleChildRenderObjectWidget {
  const _ClippedOverflowBox({
    required this.maxHeight,
    required this.onOverflowChanged,
    required super.child,
  });

  final double maxHeight;
  final ValueChanged<bool> onOverflowChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderClippedOverflow(
      maxHeight: maxHeight,
      onOverflowChanged: onOverflowChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderClippedOverflow renderObject,
  ) {
    renderObject
      ..maxHeight = maxHeight
      ..onOverflowChanged = onOverflowChanged;
  }
}

class _RenderClippedOverflow extends RenderProxyBox {
  _RenderClippedOverflow({
    required double maxHeight,
    required ValueChanged<bool> onOverflowChanged,
  }) : _maxHeight = maxHeight,
       _onOverflowChanged = onOverflowChanged;

  double _maxHeight;
  set maxHeight(double value) {
    if (_maxHeight == value) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  ValueChanged<bool> _onOverflowChanged;
  set onOverflowChanged(ValueChanged<bool> value) {
    _onOverflowChanged = value;
  }

  bool _lastReportedOverflow = false;

  @override
  void performLayout() {
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    final childHeight = child!.size.height;
    final overflow = childHeight > _maxHeight;
    size = constraints.constrain(
      Size(child!.size.width, overflow ? _maxHeight : childHeight),
    );
    if (overflow != _lastReportedOverflow) {
      _lastReportedOverflow = overflow;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onOverflowChanged(overflow);
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (child!.size.height > size.height) {
      context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        super.paint,
      );
    } else {
      super.paint(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (position.dy > size.height) return false;
    return super.hitTestChildren(result, position: position);
  }
}
