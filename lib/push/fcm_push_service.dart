import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fcm_messaging_client.dart';
import 'fcm_push_payload.dart';

typedef ShowFcmLocalNotification = void Function(FcmPushPayload payload);
typedef OpenFcmRoom = void Function(String roomId);

class FcmPushService extends ChangeNotifier {
  FcmPushService({
    FcmMessagingClient? client,
    ShowFcmLocalNotification? showLocalNotification,
    OpenFcmRoom? onOpenRoom,
  }) : _client = client ?? FirebaseFcmMessagingClient(),
       _showLocalNotification = showLocalNotification,
       _onOpenRoom = onOpenRoom;

  final FcmMessagingClient _client;
  final ShowFcmLocalNotification? _showLocalNotification;
  final OpenFcmRoom? _onOpenRoom;

  StreamSubscription<FcmRemoteMessageData>? _foregroundSub;
  StreamSubscription<FcmRemoteMessageData>? _openedSub;

  String? _token;
  String? _error;
  bool _bootstrapped = false;

  String? get token => _token;
  String? get error => _error;
  bool get available => _token != null && _token!.isNotEmpty;
  bool get bootstrapped => _bootstrapped;

  Future<void> bootstrap() async {
    try {
      await _client.requestPermission();
      _token = await _client.getToken();
      _error = null;
      _bootstrapped = true;
      await _foregroundSub?.cancel();
      await _openedSub?.cancel();
      _foregroundSub = _client.onForegroundMessage.listen(_handleForeground);
      _openedSub = _client.onMessageOpenedApp.listen(_handleOpened);
      final initial = await _client.getInitialMessage();
      if (initial != null) _handleOpened(initial);
    } catch (e) {
      _error = '$e';
      _bootstrapped = true;
    }
    notifyListeners();
  }

  Future<void> refreshToken() async {
    try {
      _token = await _client.getToken();
      _error = null;
    } catch (e) {
      _error = '$e';
    }
    notifyListeners();
  }

  void _handleForeground(FcmRemoteMessageData message) {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: message.title,
      notificationBody: message.body,
      data: message.data,
    );
    _showLocalNotification?.call(payload);
  }

  void _handleOpened(FcmRemoteMessageData message) {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: message.title,
      notificationBody: message.body,
      data: message.data,
    );
    final roomId = payload.roomId;
    if (roomId != null && roomId.isNotEmpty) {
      _onOpenRoom?.call(roomId);
    }
  }

  @override
  void dispose() {
    unawaited(_foregroundSub?.cancel());
    unawaited(_openedSub?.cancel());
    super.dispose();
  }
}
