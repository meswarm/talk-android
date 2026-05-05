import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';
import '../realtime_secretary/realtime_secretary_matrix_context.dart';
import '../realtime_secretary/realtime_secretary_models.dart';
import '../realtime_secretary/realtime_secretary_service.dart';
import '../tts/doubao_tts_service.dart';

class NotificationMessageCandidate {
  final String eventType;
  final String? messageType;
  final String? senderId;
  final String? currentUserId;
  final String roomId;
  final String? activeRoomId;
  final String body;

  const NotificationMessageCandidate({
    required this.eventType,
    required this.messageType,
    required this.senderId,
    required this.currentUserId,
    required this.roomId,
    required this.activeRoomId,
    required this.body,
  });

  bool get shouldNotifyOrStartSecretary {
    if (eventType != EventTypes.Message) return false;
    if (messageType != MessageTypes.Text) return false;
    if (senderId == currentUserId) return false;
    if (activeRoomId == roomId) return false;
    if (body.trim().isEmpty) return false;
    return true;
  }

  NotificationMessageCandidate copyWith({
    String? eventType,
    String? messageType,
    String? senderId,
    String? currentUserId,
    String? roomId,
    String? activeRoomId,
    String? body,
  }) {
    return NotificationMessageCandidate(
      eventType: eventType ?? this.eventType,
      messageType: messageType ?? this.messageType,
      senderId: senderId ?? this.senderId,
      currentUserId: currentUserId ?? this.currentUserId,
      roomId: roomId ?? this.roomId,
      activeRoomId: activeRoomId ?? this.activeRoomId,
      body: body ?? this.body,
    );
  }
}

/// 通知服务 — 监听 Matrix 新消息并弹出系统通知
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _syncSub;
  DoubaoTtsService? _voiceAnnouncementService;
  RealtimeSecretaryService? _realtimeSecretaryService;

  /// 当前正在查看的房间 ID（在此房间内不弹通知）
  String? activeRoomId;

  /// 点击通知时的回调，传入 roomId
  void Function(String roomId)? onNotificationTap;

  set voiceAnnouncementService(DoubaoTtsService? service) {
    _voiceAnnouncementService = service;
  }

  set realtimeSecretaryService(RealtimeSecretaryService? service) {
    _realtimeSecretaryService = service;
  }

  /// 初始化通知插件
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 请求 Android 13+ 通知权限
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// 开始监听 Matrix 同步中的新消息
  void startListening(Client client) {
    _syncSub?.cancel();

    _syncSub = client.onTimelineEvent.stream.listen((event) {
      final roomId = event.roomId ?? '';
      final body = event.body;
      final candidate = NotificationMessageCandidate(
        eventType: event.type,
        messageType: event.messageType,
        senderId: event.senderId,
        currentUserId: client.userID,
        roomId: roomId,
        activeRoomId: activeRoomId,
        body: body,
      );
      if (!candidate.shouldNotifyOrStartSecretary) return;

      // 获取发送者显示名和房间名
      final room = client.getRoomById(roomId);
      final senderName = _getSenderName(event.senderId, room);
      final roomName = room?.getLocalizedDisplayname() ?? '新消息';

      _showNotification(
        roomId: roomId,
        title: roomName,
        body: '$senderName: $body',
      );
      final secretary = _realtimeSecretaryService;
      if (secretary?.enabled == true) {
        if (room != null) {
          unawaited(
            secretary!.tryStartForNewTextMessage(
              roomId: roomId,
              roomName: roomName,
              triggerMessage: SecretaryTextBubble(
                senderName: senderName,
                body: body,
              ),
              contextLoader: () => loadRecentRoomTextBubbles(
                room: room,
                limit: secretary.config?.contextMessageCount ?? 3,
              ),
            ),
          );
        }
        return;
      }
      unawaited(
        _voiceAnnouncementService?.enqueueNewMessageAnnouncement(
          senderName: senderName,
          roomName: roomName,
          messageBody: body,
        ),
      );
    });
  }

  String _getSenderName(String? senderId, Room? room) {
    if (senderId == null) return '未知';
    if (room != null) {
      try {
        final user = room.unsafeGetUserFromMemoryOrFallback(senderId);
        return user.displayName ??
            senderId.split(':').first.replaceFirst('@', '');
      } catch (_) {}
    }
    return senderId.split(':').first.replaceFirst('@', '');
  }

  Future<void> _showNotification({
    required String roomId,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'talk_messages',
      '消息通知',
      channelDescription: 'Talk 聊天消息通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: roomId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: roomId,
    );
  }

  Future<void> showPushNotification({
    required String title,
    required String body,
    String? roomId,
  }) {
    return _showNotification(
      roomId: roomId ?? 'fcm-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final roomId = response.payload;
    if (roomId != null && onNotificationTap != null) {
      onNotificationTap!(roomId);
    }
  }

  /// 清除指定房间的通知
  Future<void> clearNotification(String roomId) async {
    await _plugin.cancel(id: roomId.hashCode);
  }

  /// 停止监听
  void dispose() {
    _syncSub?.cancel();
    _syncSub = null;
  }
}
