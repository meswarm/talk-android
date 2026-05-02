import 'dart:async';

import 'package:flutter/material.dart';

enum _R2MarkdownCardAction { delete }

class R2MarkdownCardShell extends StatelessWidget {
  const R2MarkdownCardShell({
    super.key,
    required this.child,
    this.onDelete,
  });

  final Widget child;
  final VoidCallback? onDelete;

  Future<void> _showMenu(BuildContext context) async {
    final action = await showModalBottomSheet<_R2MarkdownCardAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除'),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () => Navigator.of(context).pop(_R2MarkdownCardAction.delete),
          ),
        );
      },
    );
    if (action == _R2MarkdownCardAction.delete) {
      onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (onDelete == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => unawaited(_showMenu(context)),
      child: child,
    );
  }
}
