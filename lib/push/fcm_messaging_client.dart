import 'package:firebase_messaging/firebase_messaging.dart';

class FcmRemoteMessageData {
  const FcmRemoteMessageData({
    required this.title,
    required this.body,
    required this.data,
  });

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  factory FcmRemoteMessageData.fromRemoteMessage(RemoteMessage message) {
    return FcmRemoteMessageData(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
    );
  }
}

abstract class FcmMessagingClient {
  Future<void> requestPermission();
  Future<String?> getToken();
  Future<FcmRemoteMessageData?> getInitialMessage();
  Stream<FcmRemoteMessageData> get onForegroundMessage;
  Stream<FcmRemoteMessageData> get onMessageOpenedApp;
}

class FirebaseFcmMessagingClient implements FcmMessagingClient {
  FirebaseFcmMessagingClient({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null
        ? null
        : FcmRemoteMessageData.fromRemoteMessage(message);
  }

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(FcmRemoteMessageData.fromRemoteMessage);

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(
        FcmRemoteMessageData.fromRemoteMessage,
      );
}
