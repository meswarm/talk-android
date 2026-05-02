import 'package:flutter/material.dart';

/// Icon row for inserting markdown / media snippets and collapsing the composer.
///
/// Send is intentionally not shown here: users collapse to the normal composer
/// to send, reducing accidental sends while editing long Markdown.
class MarkdownComposerToolbar extends StatelessWidget {
  const MarkdownComposerToolbar({
    super.key,
    required this.enabled,
    required this.previewing,
    required this.composerText,
    required this.onTogglePreview,
    required this.onInsertCode,
    required this.onPickMediaLibrary,
    required this.onOpenCameraCapture,
    required this.onInsertFile,
    required this.onClearAll,
    required this.onCollapse,
  });

  final bool enabled;
  final bool previewing;
  /// Used to enable/disable the clear-all button when the field is empty.
  final TextEditingController composerText;
  final VoidCallback onTogglePreview;
  final VoidCallback onInsertCode;
  final VoidCallback onPickMediaLibrary;
  final VoidCallback onOpenCameraCapture;
  final VoidCallback onInsertFile;
  final VoidCallback onClearAll;
  final VoidCallback onCollapse;

  static const double _iconSize = 26;
  /// Toolbar row height ≈ prior 44×44 targets, shortened by 1/3 for vertical space.
  static const double _tap = 30;
  /// Horizontal gap between adjacent toolbar icons (easier to tap on phone).
  static const double _iconGap = 4;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      minimumSize: const Size(_tap, _tap),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    SizedBox gap() => const SizedBox(width: _iconGap);

    return Semantics(
      label: 'Composer toolbar',
      child: SizedBox(
        height: 35,
        child: Row(
          children: [
            Semantics(
              label: '媒体库',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: '媒体库',
                onPressed: enabled ? onPickMediaLibrary : null,
                icon: const Icon(Icons.perm_media_outlined),
              ),
            ),
            gap(),
            Semantics(
              label: '相机',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: '相机',
                onPressed: enabled ? onOpenCameraCapture : null,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
            ),
            gap(),
            Semantics(
              label: 'Insert file',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: 'Insert file',
                onPressed: enabled ? onInsertFile : null,
                icon: const Icon(Icons.attach_file),
              ),
            ),
            gap(),
            Semantics(
              label: 'Insert fenced code block',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: 'Insert fenced code block',
                onPressed: enabled ? onInsertCode : null,
                icon: const Icon(Icons.data_object),
              ),
            ),
            gap(),
            ListenableBuilder(
              listenable: composerText,
              builder: (context, _) {
                final hasText = composerText.text.isNotEmpty;
                return Semantics(
                  label: 'Clear all text',
                  button: true,
                  enabled: enabled && hasText,
                  child: IconButton(
                    style: style,
                    iconSize: _iconSize,
                    tooltip: 'Clear all',
                    onPressed: enabled && hasText ? onClearAll : null,
                    color: Colors.red,
                    icon: const Icon(Icons.delete_sweep),
                  ),
                );
              },
            ),
            const Spacer(),
            Semantics(
              label: previewing ? 'Edit markdown source' : 'Preview markdown',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: previewing ? 'Edit source' : 'Preview',
                onPressed: enabled ? onTogglePreview : null,
                icon: Icon(
                  previewing ? Icons.edit_note : Icons.visibility_outlined,
                ),
              ),
            ),
            gap(),
            Semantics(
              label: 'Collapse composer',
              button: true,
              enabled: enabled,
              child: IconButton(
                style: style,
                iconSize: _iconSize,
                tooltip: 'Collapse',
                onPressed: enabled ? onCollapse : null,
                icon: const Icon(Icons.expand_more),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
