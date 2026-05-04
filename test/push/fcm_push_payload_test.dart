import 'package:flutter_test/flutter_test.dart';
import 'package:talk/push/fcm_push_payload.dart';

void main() {
  test('parses notification and data fields', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: '日程todo',
      notificationBody: 'T: 当前有新任务',
      data: {
        'roomId': '!room:hs',
        'eventId': r'$event',
        'senderName': 'T',
      },
    );

    expect(payload.roomId, '!room:hs');
    expect(payload.eventId, r'$event');
    expect(payload.senderName, 'T');
    expect(payload.title, '日程todo');
    expect(payload.body, 'T: 当前有新任务');
    expect(payload.hasRoomTarget, isTrue);
  });

  test('falls back to generic title and body', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: null,
      notificationBody: null,
      data: const {},
    );

    expect(payload.title, 'Talk');
    expect(payload.body, '你有一条新消息');
    expect(payload.hasRoomTarget, isFalse);
  });

  test('trims empty fields', () {
    final payload = FcmPushPayload.fromParts(
      notificationTitle: '   ',
      notificationBody: '',
      data: const {'roomId': '   ', 'senderName': '  Alice  '},
    );

    expect(payload.title, 'Talk');
    expect(payload.body, '你有一条新消息');
    expect(payload.roomId, isNull);
    expect(payload.senderName, 'Alice');
  });
}
