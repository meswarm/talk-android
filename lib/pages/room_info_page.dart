import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '../room/room_r2_prefix.dart';
import '../r2/r2_service.dart';
import '../services/local_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/matrix_authenticated_image.dart';

enum _AvatarPickAction { gallery, camera, remove }

class RoomInfoPage extends StatefulWidget {
  final Room room;
  final String initialDisplayName;

  const RoomInfoPage({
    super.key,
    required this.room,
    required this.initialDisplayName,
  });

  @override
  State<RoomInfoPage> createState() => _RoomInfoPageState();
}

class _RoomInfoPageState extends State<RoomInfoPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _r2PrefixController;
  final FocusNode _r2PrefixFocus = FocusNode();
  StreamSubscription<SyncUpdate>? _syncSub;
  bool _nameBusy = false;
  bool _avatarBusy = false;
  bool _r2PrefixBusy = false;
  bool _leaveBusy = false;
  bool _membersLoading = true;
  List<User> _joinedMembers = const [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName);
    _r2PrefixController = TextEditingController(text: _readR2PrefixForField());
    _syncSub = widget.room.client.onSync.stream.listen((_) {
      if (!mounted) return;
      if (!_r2PrefixFocus.hasFocus) {
        _r2PrefixController.text = _readR2PrefixForField();
      }
      setState(() {});
    });
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _nameController.dispose();
    _r2PrefixController.dispose();
    _r2PrefixFocus.dispose();
    super.dispose();
  }

  String _readR2PrefixForField() {
    final state = widget.room.getState(kTalkRoomR2PrefixEventType);
    final parsed = parseRoomR2PrefixFromState(state);
    return switch (parsed) {
      RoomR2PrefixOk(:final normalized) => normalized,
      RoomR2PrefixNotConfigured() => '',
      RoomR2PrefixInvalid() => '',
    };
  }

  bool get _canEditR2Prefix =>
      widget.room.membership == Membership.join &&
      widget.room.canChangeStateEvent(kTalkRoomR2PrefixEventType);

  Future<void> _saveR2Prefix() async {
    if (!_canEditR2Prefix || _r2PrefixBusy) return;
    final result = validateRoomR2Prefix(_r2PrefixController.text);
    if (result is RoomR2PrefixInvalid) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prefix 无效: ${result.message}')));
      return;
    }
    final normalized = result is RoomR2PrefixOk ? result.normalized : '';
    setState(() => _r2PrefixBusy = true);
    try {
      await widget.room.client.setRoomStateWithKey(
        widget.room.id,
        kTalkRoomR2PrefixEventType,
        '',
        {'prefix': normalized},
      );
      if (!mounted) return;
      _r2PrefixController.text = normalized;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('R2 存储目录已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _r2PrefixBusy = false);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _membersLoading = true);
    try {
      await widget.room.requestParticipants([Membership.join]);
    } catch (_) {
      // Fall back to whatever is already cached.
    }
    if (!mounted) return;
    setState(() {
      _joinedMembers = widget.room.getParticipants([Membership.join]);
      _membersLoading = false;
    });
  }

  List<User> _sortedJoinedMembers() {
    final myId = widget.room.client.userID;
    final list = [..._joinedMembers];
    int cmp(User a, User b) {
      if (myId != null) {
        if (a.id == myId) return -1;
        if (b.id == myId) return 1;
      }
      final na = a.calcDisplayname().toLowerCase();
      final nb = b.calcDisplayname().toLowerCase();
      return na.compareTo(nb);
    }

    list.sort(cmp);
    return list;
  }

  Future<void> _saveName() async {
    final next = _nameController.text.trim();
    if (next.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称不能为空')));
      return;
    }
    final current = widget.room.getLocalizedDisplayname().trim();
    if (next == current) return;

    setState(() => _nameBusy = true);
    try {
      await widget.room.setName(next);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名称已更新')));
      Navigator.pop(context, widget.room.getLocalizedDisplayname());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    } finally {
      if (mounted) setState(() => _nameBusy = false);
    }
  }

  Future<void> _copyRoomId() async {
    await Clipboard.setData(ClipboardData(text: widget.room.id));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制 Room ID')));
  }

  /// 本机「房间提示」：聊天页顶部只读展示，便于组织要向对方说的话。
  Future<void> _editRoomNote() async {
    final initial = await LocalStorage().getRoomNote(widget.room.id);
    if (!mounted) return;
    final controller = TextEditingController(text: initial);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('房间提示'),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              maxLines: 12,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: '写给自己看的要点、模板或提醒（仅保存在本机）…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await LocalStorage().saveRoomNote(widget.room.id, controller.text);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('房间提示已保存')));
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _editQuickExtractPrompt() async {
    final initial = await LocalStorage().getRoomQuickExtractPrompt(
      widget.room.id,
    );
    if (!mounted) return;
    final controller = TextEditingController(text: initial);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('快速提取提示词'),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              maxLines: 12,
              minLines: 5,
              decoration: const InputDecoration(
                hintText:
                    '请针对所提供内容中的 markdown 表格，提取 ID 列中的每一项作为可复制选项。\n'
                    '只返回 JSON：{"items":[{"label":"ID - 标题","value":"ID"}]}。\n'
                    '顺序必须与表格从上到下完全一致。\n'
                    '不要提取标题列，不要改写，不要排序，不要去重改变顺序。',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) {
        await LocalStorage().saveRoomQuickExtractPrompt(
          widget.room.id,
          controller.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('快速提取提示词已保存')));
      }
    } finally {
      controller.dispose();
    }
  }

  /// 退出当前账号在此房间的成员身份；Matrix 上普通成员无法「删除」整个房间（需服务端管理员）。
  Future<void> _confirmAndLeave() async {
    if (widget.room.membership != Membership.join || _leaveBusy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出房间'),
        content: const Text(
          '退出后，你将不再收到此房间的消息，该会话也会从本机列表中移除。\n\n'
          '「删除整个房间」通常只能由服务器 / 管理员在后台处理；'
          '若仅需自己不再参与，选择退出即可。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出房间'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leaveBusy = true);
    try {
      await widget.room.leave();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('退出失败: $e')));
    } finally {
      if (mounted) setState(() => _leaveBusy = false);
    }
  }

  bool get _canEditAvatar =>
      widget.room.membership == Membership.join &&
      widget.room.canChangeStateEvent(EventTypes.RoomAvatar);

  bool _hasExplicitRoomAvatar() {
    final url = widget.room
        .getState(EventTypes.RoomAvatar)
        ?.content
        .tryGet<String>('url');
    return url != null && url.isNotEmpty;
  }

  Future<void> _changeRoomAvatar() async {
    final action = await showModalBottomSheet<_AvatarPickAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, _AvatarPickAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, _AvatarPickAction.camera),
            ),
            if (_hasExplicitRoomAvatar())
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  '移除房间头像',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, _AvatarPickAction.remove),
              ),
          ],
        ),
      ),
    );

    if (action == null) return;

    setState(() => _avatarBusy = true);
    try {
      if (action == _AvatarPickAction.remove) {
        await widget.room.setAvatar(null);
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已移除房间头像')));
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: action == _AvatarPickAction.gallery
            ? ImageSource.gallery
            : ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      await widget.room.setAvatar(
        MatrixFile(bytes: bytes, name: pickedFile.name),
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('房间头像已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像更新失败: $e')));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  void _onAvatarAreaTap() {
    if (_avatarBusy) return;
    if (!_canEditAvatar) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('你没有权限修改房间头像')));
      return;
    }
    unawaited(_changeRoomAvatar());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final topic = widget.room.topic.trim();
    final alias = widget.room.canonicalAlias;
    final encrypted = widget.room.encrypted;
    final roomVersionText = widget.room.roomVersion;

    final members = _sortedJoinedMembers();
    final myId = widget.room.client.userID;

    final r2 = context.watch<R2Service>();
    final bucketLabel = r2.session?.defaultBucket;
    final r2PrefixParse = parseRoomR2PrefixFromState(
      widget.room.getState(kTalkRoomR2PrefixEventType),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('房间信息')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadMembers,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('房间头像', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _onAvatarAreaTap,
                    borderRadius: BorderRadius.circular(
                      kMatrixAvatarBorderRadius,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: _avatarBusy ? 0.5 : 1,
                          child: RoomSquareAvatar(room: widget.room, size: 72),
                        ),
                        if (_avatarBusy)
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_canEditAvatar && !_avatarBusy)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(
                                  kMatrixAvatarBorderRadius,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _canEditAvatar
                          ? '点击头像从相册或相机设置，也可移除本房间单独设置的头像。'
                          : '仅具备权限的成员可更换；未设置时部分房间会显示对方头像（私聊）。',
                      style: TextStyle(
                        color: subtext,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('名称', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 255,
                    enabled: !_nameBusy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _nameBusy ? null : _saveName,
                  child: Text(_nameBusy ? '…' : '保存'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Room ID', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    widget.room.id,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _copyRoomId, child: const Text('复制')),
              ],
            ),
            const SizedBox(height: 20),
            Text('房间提示', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '仅保存在本机。在聊天页点击笔记图标可展开查看，发送消息时作参考。',
              style: TextStyle(color: subtext, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _editRoomNote,
              icon: const Icon(Icons.edit_note_outlined, size: 20),
              label: const Text('编辑房间提示'),
            ),
            const SizedBox(height: 20),
            Text('快速提取提示词', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '仅保存在本机。聊天输入区左上角图标会用它来提取最近一条对方文本消息中的候选项。',
              style: TextStyle(color: subtext, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _editQuickExtractPrompt,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
              label: const Text('编辑快速提取提示词'),
            ),
            const SizedBox(height: 20),
            Text('R2 存储目录', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Bucket 取自本机 R2 设置；Prefix 为该房间共享配置。上传会按类型写入 imgs / videos / audios / files 子目录。',
              style: TextStyle(color: subtext, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            _FactRow(label: 'Bucket', value: bucketLabel ?? '（未在本机配置 R2）'),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _r2PrefixController,
                    focusNode: _r2PrefixFocus,
                    enabled: _canEditR2Prefix && !_r2PrefixBusy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      labelText: 'Prefix',
                      hintText: '例如 team-a/A-room',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: (_canEditR2Prefix && !_r2PrefixBusy)
                      ? _saveR2Prefix
                      : null,
                  child: Text(_r2PrefixBusy ? '…' : '保存'),
                ),
              ],
            ),
            if (r2PrefixParse is RoomR2PrefixInvalid) ...[
              const SizedBox(height: 8),
              Text(
                '当前房间配置无效: ${r2PrefixParse.message}',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ],
            if (!_canEditR2Prefix && widget.room.membership == Membership.join)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '仅具备权限的成员可修改 R2 存储目录。',
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ),
            if (alias.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('别名', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SelectableText(
                alias,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
            if (topic.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('主题', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(topic, style: const TextStyle(fontSize: 14, height: 1.35)),
            ],
            const SizedBox(height: 20),
            Text('概况', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _FactRow(
              label: '成员',
              value: _membersLoading ? '加载中…' : '${members.length} 人',
            ),
            _FactRow(label: '端到端加密', value: encrypted ? '已开启' : '未开启'),
            if (roomVersionText != null && roomVersionText.isNotEmpty)
              _FactRow(label: '房间版本', value: roomVersionText),
            const SizedBox(height: 20),
            Text(
              '成员 (${members.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (_membersLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (members.isEmpty)
              Text('暂无成员数据', style: TextStyle(color: subtext))
            else
              ...members.map((m) {
                final label = m.calcDisplayname();
                final self = myId != null && m.id == myId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserSquareAvatar(user: m, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (self)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: subtext),
                                    ),
                                    child: Text(
                                      '我',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtext,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              m.id,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtext,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (widget.room.membership == Membership.join) ...[
              const SizedBox(height: 28),
              Divider(height: 1, color: subtext.withValues(alpha: 0.25)),
              const SizedBox(height: 20),
              Text(
                '离开此房间',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '不需要再看到这个会话、或房间已废弃时，可退出房间。列表会随着同步自动更新。',
                style: TextStyle(color: subtext, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: (_leaveBusy || _avatarBusy || _nameBusy)
                      ? null
                      : _confirmAndLeave,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: _leaveBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('退出房间'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: TextStyle(color: subtext, fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
