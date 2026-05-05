import 'package:flutter/material.dart';

import '../services/local_storage.dart';
import '../theme/app_colors.dart';

class CommonPhrasesSheet extends StatefulWidget {
  const CommonPhrasesSheet({
    super.key,
    required this.storage,
    required this.roomId,
    required this.onPick,
    this.maxHeight,
  });

  final LocalStorage storage;
  final String roomId;
  final ValueChanged<String> onPick;
  final double? maxHeight;

  @override
  State<CommonPhrasesSheet> createState() => _CommonPhrasesSheetState();
}

class _CommonPhrasesSheetState extends State<CommonPhrasesSheet> {
  bool _loading = true;
  bool _editing = false;
  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final phrases = await widget.storage.loadRoomCommonPhrases(widget.roomId);
    if (!mounted) return;
    setState(() {
      _replaceControllers(phrases);
      _loading = false;
    });
  }

  void _replaceControllers(List<String> phrases) {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addAll(phrases.map((phrase) => TextEditingController(text: phrase)));
  }

  List<String> _currentPhrases() => _controllers
      .map((controller) => controller.text.trim())
      .where((phrase) => phrase.isNotEmpty)
      .toList(growable: false);

  Future<void> _saveAndExitEdit() async {
    final phrases = _currentPhrases();
    await widget.storage.saveRoomCommonPhrases(widget.roomId, phrases);
    if (!mounted) return;
    setState(() {
      _replaceControllers(phrases);
      _editing = false;
    });
  }

  void _addPhrase() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removePhrase(int index) {
    setState(() {
      final controller = _controllers.removeAt(index);
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkAppBarText
        : AppColors.lightAppBarText;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final maxPanelHeight =
        widget.maxHeight ?? MediaQuery.of(context).size.height * 0.5;

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
                      Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '常用语',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_editing)
                        IconButton(
                          tooltip: '添加常用语',
                          onPressed: _addPhrase,
                          icon: const Icon(Icons.add),
                        ),
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_editing) {
                                  _saveAndExitEdit();
                                } else {
                                  setState(() => _editing = true);
                                }
                              },
                        icon: Icon(
                          _editing ? Icons.check : Icons.edit_outlined,
                        ),
                        label: Text(_editing ? '完成' : '编辑'),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: CircularProgressIndicator(),
                  )
                else if (_editing)
                  Flexible(child: _buildEditorList(isDark))
                else if (_controllers.isEmpty)
                  _buildEmptyState(subtext)
                else
                  Flexible(child: _buildPickList(isDark, subtext)),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addPhrase,
                        icon: const Icon(Icons.add),
                        label: const Text('添加常用语'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subtext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text('暂无常用语，点击编辑后添加', style: TextStyle(color: subtext)),
      ),
    );
  }

  Widget _buildPickList(bool isDark, Color subtext) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _controllers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final phrase = _controllers[index].text.trim();
        return Material(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: phrase.isEmpty
                ? null
                : () {
                    widget.onPick(phrase);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      phrase,
                      style: const TextStyle(fontSize: 16, height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.north_west_rounded, size: 18, color: subtext),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorList(bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _controllers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controllers[index],
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: '常用语 ${index + 1}',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkBackground
                      : AppColors.lightSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: () => _removePhrase(index),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        );
      },
    );
  }
}
