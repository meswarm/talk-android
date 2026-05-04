import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talk/push/fcm_messaging_client.dart';
import 'package:talk/push/fcm_push_payload.dart';
import 'package:talk/push/fcm_push_service.dart';

void main() {
  test('bootstrap requests permission and loads token', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final service = FcmPushService(client: client);

    await service.bootstrap();

    expect(client.permissionRequested, isTrue);
    expect(service.token, 'token-1');
    expect(service.available, isTrue);
    expect(service.error, isNull);
  });

  test('foreground messages are presented as local notifications', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final shown = <FcmPushPayload>[];
    final service = FcmPushService(
      client: client,
      showLocalNotification: shown.add,
    );
    await service.bootstrap();

    client.emitForeground(
      const FcmRemoteMessageData(
        title: 'Room',
        body: 'Alice: hi',
        data: {'roomId': '!r:hs'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(shown.single.roomId, '!r:hs');
    expect(shown.single.title, 'Room');
  });

  test('opened messages notify room callback', () async {
    final client = FakeFcmMessagingClient(token: 'token-1');
    final openedRooms = <String>[];
    final service = FcmPushService(client: client, onOpenRoom: openedRooms.add);
    await service.bootstrap();

    client.emitOpened(
      const FcmRemoteMessageData(
        title: 'Room',
        body: 'Alice: hi',
        data: {'roomId': '!r:hs'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(openedRooms, ['!r:hs']);
  });
}

class FakeFcmMessagingClient implements FcmMessagingClient {
  FakeFcmMessagingClient({this.token});

  final String? token;
  bool permissionRequested = false;
  final foregroundController =
      StreamController<FcmRemoteMessageData>.broadcast();
  final openedController = StreamController<FcmRemoteMessageData>.broadcast();

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage =>
      foregroundController.stream;

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp =>
      openedController.stream;

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
  }

  void emitForeground(FcmRemoteMessageData message) {
    foregroundController.add(message);
  }

  void emitOpened(FcmRemoteMessageData message) {
    openedController.add(message);
  }
}
