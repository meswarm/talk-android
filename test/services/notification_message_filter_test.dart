import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:talk/services/notification_service.dart';

void main() {
  test('notification candidate only accepts new remote text messages', () {
    const base = NotificationMessageCandidate(
      eventType: EventTypes.Message,
      messageType: MessageTypes.Text,
      senderId: '@alice:hs',
      currentUserId: '@me:hs',
      roomId: '!room:hs',
      activeRoomId: '!other:hs',
      body: 'hi',
    );

    expect(base.shouldNotifyOrStartSecretary, isTrue);
    expect(
      base
          .copyWith(eventType: EventTypes.RoomMember)
          .shouldNotifyOrStartSecretary,
      isFalse,
    );
    expect(
      base
          .copyWith(messageType: MessageTypes.Image)
          .shouldNotifyOrStartSecretary,
      isFalse,
    );
    expect(
      base.copyWith(senderId: '@me:hs').shouldNotifyOrStartSecretary,
      isFalse,
    );
    expect(
      base.copyWith(activeRoomId: '!room:hs').shouldNotifyOrStartSecretary,
      isFalse,
    );
    expect(base.copyWith(body: '   ').shouldNotifyOrStartSecretary, isFalse);
  });
}
