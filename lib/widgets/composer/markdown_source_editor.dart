import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'composer_text_selection_controls.dart';
import 'markdown_image_link_delete_formatter.dart';
import 'markdown_syntax_text_editing_controller.dart';

/// Extra blank click area below content. The send button now lives outside the
/// editor card, so we only keep a tiny cushion (no dead space below content).
const double kMarkdownSourceEditorExtraBottomPadding = 0;

/// Horizontal clearance so long wrapped lines avoid the floating send button.
/// Kept for backward compatibility; the send button is no longer overlaid, so
/// callers pass 0 in practice.
const double kMarkdownSourceEditorSendButtonRightInset = 0;

/// Multiline markdown source field for the expanded mobile composer.
class MarkdownSourceEditor extends StatelessWidget {
  const MarkdownSourceEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.bottomInset,
    this.rightInset = 0,
    required this.onChanged,
    this.readOnly = false,
  });

  final MarkdownSyntaxTextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final double bottomInset;
  final double rightInset;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkAppBarText : AppColors.lightAppBarText;
    final cursorColor =
        isDark ? AppColors.darkAppBarText : AppColors.primary;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      expands: true,
      minLines: null,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      selectionControls:
          composerTextSelectionControlsFor(Theme.of(context).platform),
      cursorWidth: 2,
      cursorColor: cursorColor,
      inputFormatters: const [MarkdownImageLinkDeleteFormatter()],
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 15,
        color: textColor,
      ),
      decoration: InputDecoration(
        filled: true,
        // Parent surface (e.g. `MobileMarkdownComposer`) paints the card color.
        fillColor: Colors.transparent,
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(
          12,
          12,
          12 + rightInset,
          12 + bottomInset + kMarkdownSourceEditorExtraBottomPadding,
        ),
      ),
    );
  }
}
