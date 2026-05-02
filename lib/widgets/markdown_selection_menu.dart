import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<ContextMenuButtonItem> markdownSelectionButtonItems(
  List<ContextMenuButtonItem> items, {
  VoidCallback? onCopyBubble,
}) {
  return items
      .where(
        (item) =>
            item.type == ContextMenuButtonType.copy ||
            item.type == ContextMenuButtonType.selectAll,
      )
      .map(
        (item) => item.copyWith(
          label: switch (item.type) {
            ContextMenuButtonType.copy => '复制',
            ContextMenuButtonType.selectAll => '复制气泡',
            _ => item.label,
          },
          onPressed: item.type == ContextMenuButtonType.selectAll
              ? onCopyBubble
              : item.onPressed,
        ),
      )
      .toList(growable: false);
}

class MarkdownSelectionArea extends StatelessWidget {
  const MarkdownSelectionArea({
    super.key,
    required this.child,
    this.sourceMarkdown,
  });

  final Widget child;
  final String? sourceMarkdown;

  void _copyBubbleMarkdown(SelectableRegionState selectableRegionState) {
    final source = sourceMarkdown;
    if (source == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: source)));
    selectableRegionState.clearSelection();
    selectableRegionState.hideToolbar();
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final buttonItems = markdownSelectionButtonItems(
      selectableRegionState.contextMenuButtonItems,
      onCopyBubble: () => _copyBubbleMarkdown(selectableRegionState),
    );
    final platform = Theme.of(context).platform;
    final anchors = selectableRegionState.contextMenuAnchors;
    if (platform == TargetPlatform.iOS) {
      return CupertinoTextSelectionToolbar(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        children: buttonItems
            .map(
              (item) => _MarkdownCupertinoSelectionButton(
                label: item.label ?? '',
                onPressed: item.onPressed,
              ),
            )
            .toList(growable: false),
      );
    }
    if (platform == TargetPlatform.android) {
      return TextSelectionToolbar(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        children: buttonItems
            .map(
              (item) => _MarkdownMaterialSelectionButton(
                label: item.label ?? '',
                onPressed: item.onPressed,
              ),
            )
            .toList(growable: false),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: buttonItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return _buildSelectionToolbar(context, selectableRegionState);
      },
      child: child,
    );
  }
}

class _MarkdownCupertinoSelectionButton extends StatelessWidget {
  const _MarkdownCupertinoSelectionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            inherit: false,
            fontSize: 15,
            letterSpacing: -0.15,
            fontWeight: FontWeight.w400,
            color: CupertinoDynamicColor.resolve(
              onPressed == null
                  ? CupertinoColors.inactiveGray
                  : CupertinoColors.black,
              context,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkdownMaterialSelectionButton extends StatelessWidget {
  const _MarkdownMaterialSelectionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      // Android selection menus can disappear before tap-up. Trigger the
      // framework's original copy/select-all callback at pointer-down time.
      onPointerDown: (_) => onPressed?.call(),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 14.5,
          end: 14.5,
          top: 11,
          bottom: 11,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onPressed == null
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
