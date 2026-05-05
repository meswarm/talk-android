import 'dart:async';
import 'dart:math' show max;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

import '../matrix/room_invite_utils.dart';
import '../matrix/timeline_messages.dart';
import '../matrix/timeline_scroll_policy.dart';
import '../matrix/typing_line.dart';
import '../theme/app_colors.dart';
import 'room_info_page.dart';
import '../r2/r2_ref.dart';
import '../r2/r2_service.dart';
import '../room/room_r2_prefix.dart';
import '../composer/composer_image_compress.dart';
import '../composer/composer_media_picker.dart';
import '../composer/composer_media_result.dart';
import '../composer/markdown_insertion.dart';
import '../quick_extract/deepseek_quick_extract_service.dart';
import '../quick_extract/quick_extract_models.dart';
import 'camera_capture_page.dart';
import '../widgets/matrix_authenticated_image.dart';
import '../widgets/composer/mobile_markdown_composer.dart';
import '../widgets/composer/markdown_syntax_text_editing_controller.dart';
import '../widgets/common_phrases_sheet.dart';
import '../widgets/quick_extract_candidates_panel.dart';
import '../widgets/chat_time_separator.dart';
import '../widgets/message_bubble.dart';
import '../widgets/room_note_hint_panel.dart';
import '../services/notification_service.dart';
import '../services/local_storage.dart';
import '../route_observer.dart';

const double _readMarkerBottomThresholdPx = 12;

class _ChatComposerSendIntent extends Intent {
  const _ChatComposerSendIntent();
}

class ChatPage extends StatefulWidget {
  final Room room;

  const ChatPage({super.key, required this.room});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with RouteAware {
  late final MarkdownSyntaxTextEditingController _messageController;
  final _scrollController = ScrollController();
  Timeline? _timeline;
  late bool _loading;
  bool _sending = false;
  bool _inviteBusy = false;
  late String _displayName;

  String? _remoteTypingLine;
  String? _lastReadMarkerEventId;

  Timer? _typingDebounceTimer;
  Timer? _typingRefreshTimer;

  StreamSubscription<SyncUpdate>? _clientSyncSub;

  bool _composerExpanded = false;
  bool _commonPhrasesVisible = false;
  bool _uploadingMedia = false;
  bool _quickExtractBusy = false;
  List<QuickExtractCandidate> _quickExtractCandidates = const [];
  bool _quickExtractPanelVisible = false;
  double _composerHeightPct = LocalStorage.defaultComposerHeightPct.toDouble();
  ComposerViewMode _composerViewMode = ComposerViewMode.source;
  final FocusNode _collapsedComposerFocus = FocusNode();
  final FocusNode _composerSourceFocus = FocusNode();

  /// 顶部「房间提示」面板显隐（仅由 AppBar 按钮切换）。
  bool _roomNotePanelVisible = false;
  String _roomNoteText = '';

  /// 当前房间是否对长文本气泡启用自动折叠（本地偏好，默认开启）。
  bool _roomAutoCollapseEnabled = true;

  bool get _toolbarMediaEnabled => !_uploadingMedia;

  static const int _typingDebounceMs = 400;
  static const int _typingTimeoutMs = 20000;
  static const int _typingRefreshMs = 10000;

  String _eventRenderKey(Event event) {
    if (event.eventId.isNotEmpty) return event.eventId;
    final txn = event.transactionId;
    if (txn != null && txn.isNotEmpty) return 'txn:$txn';
    return '${event.senderId}:${event.originServerTs.millisecondsSinceEpoch}:${event.body.hashCode}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    talkRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    talkRouteObserver.unsubscribe(this);
    _stopLocalTyping();
    _clientSyncSub?.cancel();
    _scrollController.removeListener(_onScroll);
    if (widget.room.membership == Membership.join) {
      final text = _messageController.text.trim();
      LocalStorage().saveDraft(widget.room.id, text);
    }
    NotificationService().activeRoomId = null;
    _collapsedComposerFocus.dispose();
    _composerSourceFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _timeline?.cancelSubscriptions();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id == widget.room.id) return;

    _stopLocalTyping();
    _clientSyncSub?.cancel();
    _clientSyncSub = null;
    _timeline?.cancelSubscriptions();
    _timeline = null;
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _typingRefreshTimer?.cancel();
    _typingRefreshTimer = null;

    if (oldWidget.room.membership == Membership.join) {
      final text = _messageController.text.trim();
      unawaited(LocalStorage().saveDraft(oldWidget.room.id, text));
    }

    _messageController
      ..clear()
      ..selection = const TextSelection.collapsed(offset: 0);
    _displayName = widget.room.getLocalizedDisplayname();
    _loading = widget.room.membership != Membership.invite;
    _sending = false;
    _inviteBusy = false;
    _remoteTypingLine = null;
    _lastReadMarkerEventId = null;
    _roomNotePanelVisible = false;
    _commonPhrasesVisible = false;
    _quickExtractPanelVisible = false;
    _quickExtractCandidates = const [];
    _roomNoteText = '';
    _roomAutoCollapseEnabled = true;
    NotificationService().activeRoomId = widget.room.id;
    NotificationService().clearNotification(widget.room.id);
    _subscribeTypingStreams();
    _refreshRemoteTypingLine();

    if (widget.room.membership != Membership.invite) {
      unawaited(_loadDraft());
      unawaited(_loadComposerHeightPrefs());
      unawaited(_loadRoomNote());
      unawaited(_loadRoomAutoCollapsePref());
      unawaited(_initTimeline());
    }
  }

  @override
  void didPopNext() {
    // 从设置等页返回时刷新本地保存的展开高度
    unawaited(_loadComposerHeightPrefs());
    unawaited(_loadRoomNote());
    unawaited(_loadRoomAutoCollapsePref());
  }

  @override
  void initState() {
    super.initState();
    _messageController = MarkdownSyntaxTextEditingController();
    _displayName = widget.room.getLocalizedDisplayname();
    _loading = widget.room.membership != Membership.invite;
    NotificationService().activeRoomId = widget.room.id;
    NotificationService().clearNotification(widget.room.id);
    _scrollController.addListener(_onScroll);
    _subscribeTypingStreams();
    _refreshRemoteTypingLine();
    if (widget.room.membership == Membership.invite) {
      // Invited rooms should not restore composer drafts.
    } else {
      _loadDraft();
      unawaited(_loadComposerHeightPrefs());
      unawaited(_loadRoomNote());
      unawaited(_loadRoomAutoCollapsePref());
      _initTimeline();
    }
  }

  Future<void> _loadRoomNote() async {
    final text = await LocalStorage().getRoomNote(widget.room.id);
    if (!mounted) return;
    setState(() => _roomNoteText = text);
  }

  void _toggleRoomNotePanel() {
    setState(() => _roomNotePanelVisible = !_roomNotePanelVisible);
  }

  Future<void> _loadRoomAutoCollapsePref() async {
    final v = await LocalStorage().loadRoomAutoCollapseEnabled(widget.room.id);
    if (!mounted) return;
    setState(() => _roomAutoCollapseEnabled = v);
  }

  void _toggleRoomAutoCollapse() {
    final next = !_roomAutoCollapseEnabled;
    setState(() => _roomAutoCollapseEnabled = next);
    unawaited(LocalStorage().saveRoomAutoCollapseEnabled(widget.room.id, next));
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? '已开启当前房间自动折叠' : '已关闭当前房间自动折叠')),
    );
  }

  Future<void> _loadComposerHeightPrefs() async {
    final v = await LocalStorage().loadComposerHeightPct();
    if (!mounted) return;
    setState(() => _composerHeightPct = v.toDouble());
  }

  void _subscribeTypingStreams() {
    _clientSyncSub = widget.room.client.onSync.stream.listen((update) {
      if (!mounted) return;
      if (!_syncUpdateTouchesRoom(update, widget.room.id)) return;
      _refreshRemoteTypingLine();
    });
  }

  static bool _syncUpdateTouchesRoom(SyncUpdate update, String roomId) {
    final rooms = update.rooms;
    if (rooms == null) return false;
    return (rooms.join?.containsKey(roomId) ?? false) ||
        (rooms.invite?.containsKey(roomId) ?? false) ||
        (rooms.leave?.containsKey(roomId) ?? false) ||
        (rooms.knock?.containsKey(roomId) ?? false);
  }

  void _refreshRemoteTypingLine() {
    if (widget.room.membership != Membership.join) return;
    final line = buildRemoteTypingLine(widget.room);
    if (line == _remoteTypingLine) return;
    setState(() => _remoteTypingLine = line);
  }

  void _onScroll() {
    _tryMarkRead();
  }

  bool _isScrolledToBottom() {
    final events = timelineMessagesForDisplay(_timeline?.events ?? const []);
    if (events.isEmpty) return true;
    if (!_scrollController.hasClients) return false;
    final pixels = _scrollController.position.pixels;
    return pixels.abs() <= _readMarkerBottomThresholdPx;
  }

  Future<void> _tryMarkRead({bool fromSentMessage = false}) async {
    if (widget.room.membership != Membership.join) return;
    final last = widget.room.lastEvent;
    if (last == null) return;
    if (!fromSentMessage && !_isScrolledToBottom()) return;
    if (_lastReadMarkerEventId == last.eventId) return;
    _lastReadMarkerEventId = last.eventId;
    try {
      await widget.room.setReadMarker(last.eventId, mRead: last.eventId);
    } catch (_) {}
  }

  Future<void> _markReadForEventId(String? eventId) async {
    if (widget.room.membership != Membership.join) return;
    if (eventId == null) return;
    if (_lastReadMarkerEventId == eventId) return;
    _lastReadMarkerEventId = eventId;
    try {
      await widget.room.setReadMarker(eventId, mRead: eventId);
    } catch (_) {}
  }

  void _onComposerTextChanged(String value) {
    if (widget.room.membership != Membership.join) return;
    final trimmed = value.trim();
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _typingRefreshTimer?.cancel();
    _typingRefreshTimer = null;
    if (trimmed.isEmpty) {
      unawaited(widget.room.setTyping(false));
      return;
    }
    _typingDebounceTimer = Timer(
      const Duration(milliseconds: _typingDebounceMs),
      () {
        if (!mounted) return;
        _sendTypingPing();
        _typingRefreshTimer?.cancel();
        _typingRefreshTimer = Timer.periodic(
          const Duration(milliseconds: _typingRefreshMs),
          (_) {
            if (!mounted) return;
            _sendTypingPing();
          },
        );
      },
    );
  }

  void _sendTypingPing() {
    unawaited(widget.room.setTyping(true, timeout: _typingTimeoutMs));
  }

  void _stopLocalTyping() {
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _typingRefreshTimer?.cancel();
    _typingRefreshTimer = null;
    if (widget.room.membership != Membership.join) return;
    unawaited(widget.room.setTyping(false));
  }

  Future<void> _openRoomInfoPage() async {
    if (widget.room.membership != Membership.join) return;
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RoomInfoPage(room: widget.room, initialDisplayName: _displayName),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop();
      return;
    }
    if (result is String && result.isNotEmpty) {
      setState(() => _displayName = result);
    }
    await _loadRoomNote();
  }

  Future<void> _initTimeline() async {
    try {
      final timeline = await widget.room.getTimeline(
        onChange: (_) {
          if (mounted) setState(() {});
        },
        onInsert: (index) {
          final shouldAutoScroll = shouldAutoScrollToBottomOnTimelineInsert(
            insertIndex: index,
            wasAtBottom: _isScrolledToBottom(),
            userScrollInProgress:
                _scrollController.hasClients &&
                _scrollController.position.isScrollingNotifier.value,
          );
          if (mounted) setState(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (shouldAutoScroll && _scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
            _tryMarkRead();
          });
        },
      );

      if (mounted) {
        setState(() {
          _timeline = timeline;
          _loading = false;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryMarkRead();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _uploadingMedia) return;

    setState(() => _sending = true);
    _messageController.clear();
    _stopLocalTyping();

    try {
      final eventId = await widget.room.sendTextEvent(
        text,
        parseCommands: false,
        displayPendingEvent: false,
      );
      await LocalStorage().clearDraft(widget.room.id);
      if (!mounted) return;
      await _markReadForEventId(eventId ?? widget.room.lastEvent?.eventId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadDraft() async {
    final draft = await LocalStorage().getDraft(widget.room.id);
    if (draft.isNotEmpty && mounted) {
      _messageController.text = draft;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: draft.length),
      );
    }
  }

  Future<void> _acceptInvite() async {
    setState(() => _inviteBusy = true);
    try {
      await widget.room.join();
      if (!mounted) return;
      setState(() => _loading = true);
      await _initTimeline();
      if (mounted) {
        unawaited(_loadRoomAutoCollapsePref());
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法接受邀请: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  Future<void> _declineInvite() async {
    setState(() => _inviteBusy = true);
    try {
      await widget.room.leave();
      if (!mounted || !context.mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法拒绝邀请: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  /// 展开后源码输入框挂载完成再聚焦，否则光标不会出现。
  void _focusComposerSourceAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_composerExpanded) return;
      if (_composerViewMode != ComposerViewMode.source) return;
      _collapsedComposerFocus.unfocus();
      _composerSourceFocus.requestFocus();
    });
  }

  void _expandComposer() {
    if (_composerExpanded) return;
    setState(() {
      _composerExpanded = true;
      _commonPhrasesVisible = false;
      _quickExtractPanelVisible = false;
      _composerViewMode = ComposerViewMode.source;
    });
    _focusComposerSourceAfterBuild();
  }

  void _collapseComposer() {
    if (!_composerExpanded) return;
    setState(() {
      _composerExpanded = false;
    });
  }

  void _insertCodeBlockFromToolbar() {
    if (!_toolbarMediaEnabled) return;
    _insertComposerSnippet('```\n\n```');
  }

  Event? _latestIncomingTextEvent() {
    final myId = widget.room.client.userID;
    final events = timelineMessagesForDisplay(_timeline?.events ?? const []);
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.senderId == myId) continue;
      if (event.type != EventTypes.Message) continue;
      if (event.messageType != MessageTypes.Text) continue;
      if (event.body.trim().isEmpty) continue;
      return event;
    }
    return null;
  }

  void _insertQuickExtractValue(String value) {
    if (mounted) {
      setState(() => _quickExtractPanelVisible = false);
    }
    _insertTextIntoCollapsedComposer(value, appendOnExistingText: true);
  }

  void _insertCommonPhraseValue(String value) {
    if (mounted) {
      setState(() => _commonPhrasesVisible = false);
    }
    _insertTextIntoCollapsedComposer(value);
  }

  void _insertTextIntoCollapsedComposer(
    String value, {
    bool appendOnExistingText = false,
  }) {
    if (!mounted) return;
    final current = _messageController.text;
    final selection = _messageController.selection;
    final insertion = appendOnExistingText && current.trim().isNotEmpty
        ? '\n$value'
        : value;
    final start = selection.isValid ? selection.start : current.length;
    final end = selection.isValid ? selection.end : current.length;
    final next = current.replaceRange(start, end, insertion);
    final cursor = start + insertion.length;
    _messageController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    _onComposerTextChanged(next);
    unawaited(LocalStorage().saveDraft(widget.room.id, next));
    _collapsedComposerFocus.requestFocus();
  }

  void _toggleCommonPhrasesPanel() {
    if (_uploadingMedia) return;
    setState(() {
      _commonPhrasesVisible = !_commonPhrasesVisible;
      if (_commonPhrasesVisible) _quickExtractPanelVisible = false;
    });
  }

  void _showQuickExtractCandidates(List<QuickExtractCandidate> items) {
    final messenger = ScaffoldMessenger.of(context);
    if (items.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('未提取到选项')));
      return;
    }
    setState(() {
      _quickExtractCandidates = items;
      _quickExtractPanelVisible = true;
      _commonPhrasesVisible = false;
    });
  }

  Future<void> _runQuickExtract() async {
    if (_quickExtractBusy || _uploadingMedia) return;
    final service = context.read<DeepSeekQuickExtractService>();
    final config = service.config;
    if (config == null || !config.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在个人资料页配置 DeepSeek')));
      return;
    }
    final prompt = await LocalStorage().getRoomQuickExtractPrompt(
      widget.room.id,
    );
    if (!mounted) return;
    if (prompt.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在房间设置中配置快速提取提示词')));
      return;
    }
    final event = _latestIncomingTextEvent();
    if (event == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可提取的对方文本消息')));
      return;
    }

    setState(() => _quickExtractBusy = true);
    try {
      final items = await service.extract(
        config: config,
        roomPrompt: prompt,
        markdown: event.body,
      );
      if (!mounted) return;
      _showQuickExtractCandidates(items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('快速提取失败: $e')));
    } finally {
      if (mounted) setState(() => _quickExtractBusy = false);
    }
  }

  void _clearComposerContent() {
    if (!mounted || _uploadingMedia) return;
    setState(() {
      _messageController.clear();
    });
    _stopLocalTyping();
    unawaited(LocalStorage().saveDraft(widget.room.id, ''));
    if (_composerExpanded) {
      _focusComposerSourceAfterBuild();
    }
  }

  void _insertComposerSnippet(String snippet) {
    if (!mounted) return;
    setState(() {
      _composerExpanded = true;
    });
    final next = insertMarkdownSnippet(
      text: _messageController.text,
      selection: _messageController.selection,
      snippet: snippet,
    );
    _messageController.value = next;
    unawaited(LocalStorage().saveDraft(widget.room.id, next.text));
  }

  /// Composer media is R2-only. Matrix still carries the Markdown text event.
  bool _canInsertComposerMedia() {
    if (!mounted) return false;
    if (widget.room.encrypted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加密房间暂不支持将媒体插入 Markdown，请改用非加密房间或外部链接。')),
      );
      return false;
    }
    return true;
  }

  Future<void> _uploadR2AndInsertMarkdown({
    required Uint8List bytes,
    required String name,
    required String mime,
  }) async {
    final r2 = context.read<R2Service>();
    if (r2.session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 R2 凭据（默认 Bucket 等）。')),
      );
      return;
    }
    final prefixState = parseRoomR2PrefixFromState(
      widget.room.getState(kTalkRoomR2PrefixEventType),
    );
    late final String roomPrefix;
    switch (prefixState) {
      case RoomR2PrefixInvalid(:final message):
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('房间 R2 存储目录配置无效: $message。请在房间信息中修正 Prefix。'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      case RoomR2PrefixNotConfigured():
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在房间信息中设置 R2 存储目录（Prefix），再上传媒体或文件。')),
        );
        return;
      case RoomR2PrefixOk(:final normalized):
        roomPrefix = normalized;
    }

    setState(() => _uploadingMedia = true);
    _stopLocalTyping();
    try {
      final ref = await r2.uploadAttachment(
        bytes: bytes,
        fileName: name,
        mime: mime,
        roomPrefix: roomPrefix,
      );
      final snippet = r2MarkdownSnippet(name, mime, ref);
      if (!mounted) return;
      _insertComposerSnippet(snippet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('R2 插入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _onPickMediaLibrary() async {
    if (!_toolbarMediaEnabled) return;
    if (!_canInsertComposerMedia()) return;
    final picked = await ComposerMediaPicker.showLibraryChoiceAndPick(context);
    if (!mounted || picked == null) return;
    await _ingestComposerMedia(picked);
  }

  Future<void> _onOpenCameraCapture() async {
    if (!_toolbarMediaEnabled) return;
    if (!_canInsertComposerMedia()) return;
    final result = await Navigator.of(context).push<ComposerMediaResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCapturePage(),
      ),
    );
    if (!mounted || result == null) return;
    await _ingestComposerMedia(result);
  }

  Future<void> _ingestComposerMedia(ComposerMediaResult media) async {
    if (!_toolbarMediaEnabled) return;
    if (!_canInsertComposerMedia()) return;
    final r2 = context.read<R2Service>();
    if (r2.session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 R2 凭据（默认 Bucket 等）。')),
      );
      return;
    }
    if (media.bytes.isEmpty) return;
    final compressOn = await LocalStorage().loadCompressUploadImages();
    final prepared = await applyChatImageCompressionIfEnabled(
      media,
      enabled: compressOn,
    );
    await _uploadR2AndInsertMarkdown(
      bytes: prepared.bytes,
      name: prepared.fileName,
      mime: prepared.mime,
    );
  }

  Future<void> _pickAndSendFile() async {
    if (!_toolbarMediaEnabled) return;
    if (!_canInsertComposerMedia()) return;
    final r2 = context.read<R2Service>();
    if (r2.session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 R2 凭据（默认 Bucket 等）。')),
      );
      return;
    }
    final result = await FilePicker.pickFiles(withData: true);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final name = picked.name;
    final mime =
        lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream';
    final compressOn = await LocalStorage().loadCompressUploadImages();
    final wrapped = ComposerMediaResult(
      bytes: Uint8List.fromList(bytes),
      fileName: name,
      mime: mime,
    );
    final prepared = await applyChatImageCompressionIfEnabled(
      wrapped,
      enabled: compressOn,
    );
    await _uploadR2AndInsertMarkdown(
      bytes: prepared.bytes,
      name: prepared.fileName,
      mime: prepared.mime,
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final controller = TextEditingController();

    final userId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请用户'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '@username:server',
            prefixIcon: Icon(Icons.alternate_email),
            labelText: 'Matrix ID',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('邀请'),
          ),
        ],
      ),
    );

    if (userId == null || userId.isEmpty) return;

    try {
      await widget.room.invite(userId);
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已发送邀请给 $userId'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('邀请失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _inviterLabel() {
    final inviterId = getRoomInviteInviterId(widget.room);
    if (inviterId == null) return '';
    final member = widget.room.unsafeGetUserFromMemoryOrFallback(inviterId);
    final name = member.calcDisplayname().trim();
    if (name.isNotEmpty) return name;
    return inviterId.localpart ?? inviterId;
  }

  Widget _buildInviteBody(bool isDark) {
    final displayName = widget.room.getLocalizedDisplayname();
    final inviterLabel = _inviterLabel();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '房间邀请',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkAppBarText
                    : AppColors.lightAppBarText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
            if (inviterLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '邀请人：$inviterLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '接受后将加入房间并可以参与聊天。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: _inviteBusy ? null : _acceptInvite,
                  child: Text(_inviteBusy ? '处理中…' : '接受邀请'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _inviteBusy ? null : _declineInvite,
                  child: Text(_inviteBusy ? '处理中…' : '拒绝邀请'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInvite = widget.room.membership == Membership.invite;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: isInvite ? null : _openRoomInfoPage,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              RoomSquareAvatar(room: widget.room, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isInvite ? '房间邀请' : _displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isInvite) ...[
            IconButton(
              icon: Icon(
                _roomAutoCollapseEnabled
                    ? Icons.unfold_less
                    : Icons.unfold_more,
                size: 22,
              ),
              onPressed: _toggleRoomAutoCollapse,
              tooltip: _roomAutoCollapseEnabled ? '关闭当前房间的自动折叠' : '开启当前房间的自动折叠',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
            IconButton(
              icon: Icon(
                _roomNotePanelVisible
                    ? Icons.lightbulb
                    : Icons.lightbulb_outline,
                size: 22,
              ),
              onPressed: _toggleRoomNotePanel,
              tooltip: _roomNotePanelVisible ? '隐藏提示面板' : '显示提示面板',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_outlined, size: 20),
              onPressed: () => _showInviteDialog(context),
              tooltip: '邀请用户',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
          ],
        ],
      ),
      body: isInvite
          ? _buildInviteBody(isDark)
          : LayoutBuilder(
              builder: (context, constraints) {
                final panelH = max(120.0, constraints.maxHeight);
                return Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _roomNotePanelVisible
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: RoomNoteHintPanel(
                                isDark: isDark,
                                text: _roomNoteText,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : _buildMessageList(isDark),
                    ),
                    if (_remoteTypingLine != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _remoteTypingLine!,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                          ),
                        ),
                      ),
                    TapRegion(
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: _buildComposerShell(isDark, panelH),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    final events = timelineMessagesForDisplay(_timeline?.events ?? const []);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: isDark
                  ? AppColors.darkSubtext.withValues(alpha: 0.5)
                  : AppColors.lightSubtext.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '发送第一条消息吧',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey<String>('chat-list:${widget.room.id}'),
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isOwnMessage = event.senderId == widget.room.client.userID;

        final showSep =
            index < events.length - 1 &&
            event.originServerTs
                    .difference(events[index + 1].originServerTs)
                    .abs() >=
                kChatTimeSeparatorGap;

        return Column(
          key: ValueKey<String>('msg:${_eventRenderKey(event)}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showSep)
              ChatTimeSeparator(
                referenceTime: events[index + 1].originServerTs,
              ),
            MessageBubble(
              key: ValueKey<String>('bubble:${_eventRenderKey(event)}'),
              event: event,
              isOwnMessage: isOwnMessage,
              room: widget.room,
              autoCollapseEnabled: _roomAutoCollapseEnabled,
            ),
          ],
        );
      },
    );
  }

  BoxDecoration _composerBarDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, -1),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return ListenableBuilder(
      listenable: _messageController,
      builder: (context, _) {
        final canSend =
            _messageController.text.trim().isNotEmpty &&
            !_sending &&
            !_uploadingMedia;
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: (_sending || _uploadingMedia)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
              onPressed: canSend ? _sendMessage : null,
              padding: EdgeInsets.zero,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedToolbarIcon({
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
    double iconSize = 24,
  }) {
    final side = (iconSize + 8).clamp(28.0, 44.0);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: iconSize,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        constraints: BoxConstraints(minWidth: side, minHeight: side),
        style: IconButton.styleFrom(
          minimumSize: Size(side, side),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: icon,
      ),
    );
  }

  Widget _buildComposerShell(bool isDark, double panelH) {
    if (_composerExpanded) {
      return DecoratedBox(
        decoration: _composerBarDecoration(isDark),
        child: _buildExpandedComposer(isDark, panelH),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: _quickExtractPanelVisible
              ? QuickExtractCandidatesPanel(
                  items: _quickExtractCandidates,
                  onPick: (item) {
                    unawaited(
                      Clipboard.setData(ClipboardData(text: item.value)),
                    );
                    _insertQuickExtractValue(item.value);
                  },
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                )
              : _commonPhrasesVisible
              ? CommonPhrasesSheet(
                  storage: LocalStorage(),
                  roomId: widget.room.id,
                  onPick: _insertCommonPhraseValue,
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                )
              : const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: _composerBarDecoration(isDark),
          child: _buildCollapsedComposer(isDark),
        ),
      ],
    );
  }

  Widget _buildCollapsedComposer(bool isDark) {
    final bottom = MediaQuery.of(context).padding.bottom + 8;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _ChatComposerSendIntent(),
        SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _ChatComposerSendIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ChatComposerSendIntent: CallbackAction<_ChatComposerSendIntent>(
            onInvoke: (_) {
              unawaited(_sendMessage());
              return null;
            },
          ),
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 3, 8, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    _buildCollapsedToolbarIcon(
                      tooltip: '快速提取',
                      onPressed: (_uploadingMedia || _quickExtractBusy)
                          ? null
                          : () => unawaited(_runQuickExtract()),
                      iconSize: 31,
                      icon: _quickExtractBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high_outlined),
                    ),
                    const SizedBox(width: 12),
                    _buildCollapsedToolbarIcon(
                      tooltip: '常用语',
                      onPressed: _uploadingMedia
                          ? null
                          : _toggleCommonPhrasesPanel,
                      iconSize: 31,
                      icon: Icon(
                        _commonPhrasesVisible
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.quickreply_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: divider, width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: isDark
                                    ? AppColors.darkBackground
                                    : AppColors.lightBackground,
                              ),
                            ),
                            TextField(
                              controller: _messageController,
                              focusNode: _collapsedComposerFocus,
                              minLines: 1,
                              maxLines: 1,
                              textInputAction: TextInputAction.newline,
                              readOnly: _uploadingMedia || _quickExtractBusy,
                              onChanged: _onComposerTextChanged,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                hintText: _uploadingMedia ? '上传中…' : '输入消息…',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.lightSubtext,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  52,
                                  10,
                                ),
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? AppColors.darkAppBarText
                                    : AppColors.lightAppBarText,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: IconButton(
                                  tooltip: 'Markdown 编辑',
                                  onPressed: _uploadingMedia
                                      ? null
                                      : _expandComposer,
                                  iconSize: 24,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: Icon(
                                    Icons.article_outlined,
                                    color: _uploadingMedia
                                        ? AppColors.primary.withValues(
                                            alpha: 0.35,
                                          )
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            _CollapsedComposerInnerShadow(isDark: isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 40, child: _buildSendButton()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedComposer(bool isDark, double panelH) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // No send shortcut here: Markdown mode hides the send control; user must
    // collapse to the normal composer to send (see `_buildCollapsedComposer`).
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: MobileMarkdownComposer(
        controller: _messageController,
        focusNode: _composerSourceFocus,
        isDark: isDark,
        panelHeight: panelH,
        composerHeightPct: _composerHeightPct,
        viewMode: _composerViewMode,
        onTogglePreview: () {
          final next = _composerViewMode == ComposerViewMode.source
              ? ComposerViewMode.preview
              : ComposerViewMode.source;
          setState(() => _composerViewMode = next);
          if (next == ComposerViewMode.source) {
            _focusComposerSourceAfterBuild();
          }
        },
        uploadingMedia: _uploadingMedia,
        onChanged: _onComposerTextChanged,
        onInsertCode: _insertCodeBlockFromToolbar,
        onPickMediaLibrary: _onPickMediaLibrary,
        onOpenCameraCapture: _onOpenCameraCapture,
        onInsertFile: _pickAndSendFile,
        onClearAll: _clearComposerContent,
        onCollapse: _collapseComposer,
        onHeightPctChanged: (next) {
          setState(() => _composerHeightPct = next);
          unawaited(
            LocalStorage().saveComposerHeightPct(_composerHeightPct.round()),
          );
        },
      ),
    );
  }
}

/// Subtle inset along the collapsed composer pill (lighter than Markdown card).
class _CollapsedComposerInnerShadow extends StatelessWidget {
  const _CollapsedComposerInnerShadow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final edge = isDark ? 0.10 : 0.022;
    final side = isDark ? 0.07 : 0.018;
    const radius = 20.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 4,
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
                height: 4,
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
                width: 3,
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
                width: 3,
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
