import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';
import '../tts/doubao_tts_service.dart';

/// 通知服务 — 监听 Matrix 新消息并弹出系统通知
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _syncSub;
  DoubaoTtsService? _voiceAnnouncementService;

  /// 当前正在查看的房间 ID（在此房间内不弹通知）
  String? activeRoomId;

  /// 点击通知时的回调，传入 roomId
  void Function(String roomId)? onNotificationTap;

  set voiceAnnouncementService(DoubaoTtsService? service) {
    _voiceAnnouncementService = service;
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
      // 跳过非消息类型
      if (event.type != EventTypes.Message) return;

      // 跳过自己发送的消息
      if (event.senderId == client.userID) return;

      // 当前正在聊天的房间不弹通知
      final roomId = event.roomId ?? '';
      if (activeRoomId == roomId) return;

      final body = event.body;
      if (body.isEmpty) return;

      // 获取发送者显示名和房间名
      final room = client.getRoomById(roomId);
      final senderName = _getSenderName(event.senderId, room);
      final roomName = room?.getLocalizedDisplayname() ?? '新消息';

      _showNotification(
        roomId: roomId,
        title: roomName,
        body: '$senderName: $body',
      );
      unawaited(
        _voiceAnnouncementService?.enqueueNewMessageAnnouncement(
          senderName: senderName,
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
