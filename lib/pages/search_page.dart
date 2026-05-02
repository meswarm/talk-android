import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/matrix_authenticated_image.dart';
import 'chat_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _searching = true);

    final chatProvider = context.read<ChatProvider>();
    final rooms = chatProvider.rooms;
    final results = <_SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final room in rooms) {
      try {
        final timeline = await room.getTimeline();
        for (final event in timeline.events) {
          if (event.type != EventTypes.Message) continue;

          final body = event.body.toLowerCase();
          if (body.contains(lowerQuery)) {
            results.add(_SearchResult(
              room: room,
              event: event,
              roomName: room.getLocalizedDisplayname(),
            ));
          }

          // 限制每个房间最多10条结果
          if (results.where((r) => r.room.id == room.id).length >= 10) break;
        }
        timeline.cancelSubscriptions();
      } catch (_) {}
    }

    // 按时间倒序排列
    results.sort((a, b) =>
        b.event.originServerTs.compareTo(a.event.originServerTs));

    if (mounted) {
      setState(() {
        _results = results.take(50).toList();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            color: isDark ? AppColors.darkAppBarText : AppColors.lightAppBarText,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: '搜索聊天记录...',
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            ),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (value) => _performSearch(value),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _searching
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _results.isEmpty
              ? _buildEmptyState(isDark)
              : _buildResultList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasQuery = _searchController.text.trim().length >= 2;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.search,
            size: 48,
            color: isDark
                ? AppColors.darkSubtext.withValues(alpha: 0.5)
                : AppColors.lightSubtext.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? '未找到相关消息' : '输入关键词搜索',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(bool isDark) {
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        indent: searchResultDividerIndent(context),
        endIndent: conversationListTileHorizontalPadding(context),
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      ),
      itemBuilder: (context, index) {
        final result = _results[index];
        final senderName = result.event.senderFromMemoryOrFallback.displayName ??
            result.event.senderId;
        final sf = MediaQuery.textScalerOf(context).scale(1.0);
        final hPad = conversationListTileHorizontalPadding(context);
        final vPad = (12.0 * sf).clamp(10.0, 28.0);
        final avatarSize = searchResultAvatarSize(context);
        final avatarGap = searchResultAvatarGap(context);
        final rowGap = (6.0 * sf).clamp(4.0, 14.0);
        final bodyLeft = avatarSize + avatarGap;

        return InkWell(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(room: result.room),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 房间名 + 时间
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RoomSquareAvatar(
                      room: result.room,
                      size: avatarSize,
                    ),
                    SizedBox(width: avatarGap),
                    Expanded(
                      child: Text(
                        result.roomName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkAppBarText
                              : AppColors.lightAppBarText,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(result.event.originServerTs),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: rowGap),
                // 发送者: 消息内容
                Padding(
                  padding: EdgeInsets.only(left: bodyLeft),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$senderName: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkAppBarText
                                : AppColors.lightAppBarText,
                          ),
                        ),
                        TextSpan(
                          text: result.event.body.length > 100
                              ? '${result.event.body.substring(0, 100)}...'
                              : result.event.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }
    return '${time.month}/${time.day}';
  }
}

class _SearchResult {
  final Room room;
  final Event event;
  final String roomName;

  _SearchResult({
    required this.room,
    required this.event,
    required this.roomName,
  });
}
