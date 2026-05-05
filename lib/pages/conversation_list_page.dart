import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../realtime_secretary/realtime_secretary_debug_panel.dart';
import '../realtime_secretary/realtime_secretary_service.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/matrix_authenticated_image.dart';
import '../theme/app_colors.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  bool _creating = false;
  Uri? _selfAvatarUri;

  @override
  void initState() {
    super.initState();
    _loadSelfAvatar();
  }

  Future<void> _loadSelfAvatar() async {
    final auth = context.read<AuthProvider>();
    final uri = await auth.matrixService.getOwnAvatarDownloadUri();
    if (mounted) setState(() => _selfAvatarUri = uri);
  }

  String _leadingInitial(String? userId) {
    if (userId == null || userId.isEmpty) return '?';
    final local = userId.split(':').first.replaceFirst('@', '');
    if (local.isEmpty) return '?';
    return local[0].toUpperCase();
  }

  Future<void> _showCreateRoomDialog() async {
    final nameController = TextEditingController();

    final roomName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建房间'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入房间名称',
            prefixIcon: Icon(Icons.chat_bubble_outline),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (roomName == null || roomName.isEmpty) return;
    if (!mounted) return;

    setState(() => _creating = true);

    try {
      final auth = context.read<AuthProvider>();
      final client = auth.matrixService.client;
      final roomId = await client.createRoom(
        name: roomName,
        preset: CreateRoomPreset.trustedPrivateChat,
      );

      // 等待同步获取到新房间
      await client.waitForRoomInSync(roomId, join: true);
      final room = client.getRoomById(roomId);

      if (mounted && room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatPage(room: room)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _acceptInvite(Room room) async {
    try {
      await room.join();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('接受邀请失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _declineInvite(Room room) async {
    try {
      await room.leave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拒绝邀请失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPinSheet(ChatProvider chat, Room room) {
    final pinned = chat.isRoomPinned(room.id);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(pinned ? '取消置顶' : '置顶'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                try {
                  if (pinned) {
                    await chat.unpinRoom(room.id);
                  } else {
                    await chat.pinRoom(room.id);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('置顶操作失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final client = auth.matrixService.client;
    final userId = client.userID;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final joined = chatProvider.joinedRoomsPinnedSorted;
    final invites = chatProvider.invitedRooms;
    final hasAny = joined.isNotEmpty || invites.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 45,
        leadingWidth: 104,
        // 头像 + 新建房间；toolbarHeight 45 时上下留白凑满 40×40 头像。
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 0, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                  if (mounted) await _loadSelfAvatar();
                },
                child: MatrixAuthenticatedSquareAvatar(
                  uri: _selfAvatarUri,
                  client: client,
                  size: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  fallback: Text(
                    _leadingInitial(userId),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: '新建房间',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: _creating ? null : _showCreateRoomDialog,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
            tooltip: '搜索',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            tooltip: '设置',
          ),
        ],
      ),
      body: Stack(
        children: [
          !hasAny
              ? _buildEmptyState(isDark)
              : ListView(
                  children: [
                    if (invites.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          '邀请',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                        ),
                      ),
                      for (var i = 0; i < invites.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: inviteRowDividerIndent(context),
                            endIndent: 16,
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.lightDivider,
                          ),
                        _InviteRow(
                          room: invites[i],
                          displayName: chatProvider.getRoomDisplayName(
                            invites[i],
                          ),
                          preview: chatProvider.getLastMessagePreview(
                            invites[i],
                          ),
                          isDark: isDark,
                          onAccept: () => _acceptInvite(invites[i]),
                          onDecline: () => _declineInvite(invites[i]),
                        ),
                      ],
                      if (joined.isNotEmpty)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                    ],
                    for (var j = 0; j < joined.length; j++) ...[
                      if (j > 0)
                        Divider(
                          height: 1,
                          indent: conversationListDividerIndent(context),
                          endIndent: 16,
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.lightDivider,
                        ),
                      ConversationTile(
                        room: joined[j],
                        displayName: chatProvider.getRoomDisplayName(joined[j]),
                        lastMessage: chatProvider.getLastMessagePreview(
                          joined[j],
                        ),
                        isPinned: chatProvider.isRoomPinned(joined[j].id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(room: joined[j]),
                            ),
                          );
                        },
                        onLongPress: () =>
                            _showPinSheet(chatProvider, joined[j]),
                      ),
                    ],
                  ],
                ),
          Consumer<RealtimeSecretaryService>(
            builder: (context, secretary, _) {
              if (!secretary.shouldShowDebugConversation) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: RealtimeSecretaryDebugPanel(
                    state: secretary.state,
                    entries: secretary.debugConversationEntries,
                  ),
                ),
              );
            },
          ),
          if (_creating)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无会话',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkAppBarText
                  : AppColors.lightAppBarText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击左上角头像旁的 + 创建新房间',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  final Room room;
  final String displayName;
  final String preview;
  final bool isDark;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteRow({
    required this.room,
    required this.displayName,
    required this.preview,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final sf = MediaQuery.textScalerOf(context).scale(1.0);
    final avatarSize = conversationListAvatarSize(context);
    final hPad = inviteRowHorizontalPadding(context);
    final vPad = (8.0 * sf).clamp(6.0, 20.0);
    final gap = conversationListTileAvatarGap(context);
    final titlePreviewGap = (4.0 * sf).clamp(3.0, 10.0);
    final beforeActionsGap = (8.0 * sf).clamp(6.0, 16.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoomSquareAvatar(room: room, size: avatarSize),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkAppBarText
                        : AppColors.lightAppBarText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preview.isNotEmpty) ...[
                  SizedBox(height: titlePreviewGap),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: beforeActionsGap),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(onPressed: onDecline, child: const Text('拒绝')),
                    FilledButton.tonal(
                      onPressed: onAccept,
                      child: const Text('接受'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
