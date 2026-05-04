import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:talk/pages/push_notification_settings_page.dart';
import 'package:talk/push/fcm_messaging_client.dart';
import 'package:talk/push/fcm_push_service.dart';

void main() {
  testWidgets('shows token and refresh action', (tester) async {
    final service = FcmPushService(client: _TokenClient('token-abc'));
    await service.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<FcmPushService>.value(
        value: service,
        child: const MaterialApp(home: PushNotificationSettingsPage()),
      ),
    );

    expect(find.text('FCM 推送通知'), findsOneWidget);
    expect(find.text('token-abc'), findsOneWidget);
    expect(find.text('刷新 Token'), findsOneWidget);
  });
}

class _TokenClient implements FcmMessagingClient {
  _TokenClient(this.token);

  final String token;

  @override
  Stream<FcmRemoteMessageData> get onForegroundMessage => const Stream.empty();

  @override
  Stream<FcmRemoteMessageData> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<FcmRemoteMessageData?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> requestPermission() async {}
}
