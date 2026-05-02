import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

import 'package:talk/matrix/timeline_messages.dart';

class _FakeDatabase extends Fake implements DatabaseApi {}

Event _messageEvent({
  required Room room,
  required String eventId,
  required String senderId,
  required String body,
  required int originServerTsMs,
  required EventStatus status,
  String? transactionId,
}) {
  return Event(
    status: status,
    content: {'msgtype': MessageTypes.Text, 'body': body},
    type: EventTypes.Message,
    eventId: eventId,
    senderId: senderId,
    originServerTs: DateTime.fromMillisecondsSinceEpoch(originServerTsMs),
    unsigned: transactionId == null ? null : {'transaction_id': transactionId},
    room: room,
  );
}

void main() {
  test('filters out non-m.room.message / non-sticker events', () {
    final out = timelineMessageSurfacesForDisplay(const [
      TimelineMessageSurface(
        type: EventTypes.RoomMember,
        relationshipType: null,
        eventId: 'a',
        transactionId: null,
      ),
      TimelineMessageSurface(
        type: EventTypes.Message,
        relationshipType: null,
        eventId: 'b',
        transactionId: null,
      ),
    ]);
    expect(out.map((s) => s.eventId).toList(), ['b']);
  });

  test('filters m.replace edits', () {
    final out = timelineMessageSurfacesForDisplay(const [
      TimelineMessageSurface(
        type: EventTypes.Message,
        relationshipType: RelationshipTypes.edit,
        eventId: 'edit1',
        transactionId: null,
      ),
      TimelineMessageSurface(
        type: EventTypes.Message,
        relationshipType: null,
        eventId: 'orig',
        transactionId: null,
      ),
    ]);
    expect(out.map((s) => s.eventId).toList(), ['orig']);
  });

  test('dedupes duplicate event ids (stable order)', () {
    const a = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: 'dup',
      transactionId: null,
    );
    const b = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: 'dup',
      transactionId: null,
    );
    final out = timelineMessageSurfacesForDisplay([a, b]);
    expect(out, [a]);
  });

  test('dedupes by transaction_id keeping last occurrence', () {
    const a = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: 'local1',
      transactionId: 'tx1',
    );
    const b = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: 'srv1',
      transactionId: 'tx1',
    );
    final out = timelineMessageSurfacesForDisplay([a, b]);
    expect(out.map((s) => s.eventId).toList(), ['srv1']);
  });

  test(
    'dedupes unsynced local echo by same sender body and nearby synced event',
    () {
      const localEcho = TimelineMessageSurface(
        type: EventTypes.Message,
        relationshipType: null,
        eventId: 'tx-local',
        transactionId: null,
        senderId: '@me:example.org',
        body: '当前我有哪些订阅?',
        originServerTsMs: 100000,
        status: EventStatus.sent,
      );
      const synced = TimelineMessageSurface(
        type: EventTypes.Message,
        relationshipType: null,
        eventId: r'$server',
        transactionId: null,
        senderId: '@me:example.org',
        body: '当前我有哪些订阅?',
        originServerTsMs: 101000,
        status: EventStatus.synced,
      );

      final out = timelineMessageSurfacesForDisplay([localEcho, synced]);

      expect(out.map((s) => s.eventId).toList(), [r'$server']);
    },
  );

  test('keeps intentional repeated synced messages with same body', () {
    const first = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: r'$first',
      transactionId: null,
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 100000,
      status: EventStatus.synced,
    );
    const second = TimelineMessageSurface(
      type: EventTypes.Message,
      relationshipType: null,
      eventId: r'$second',
      transactionId: null,
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 101000,
      status: EventStatus.synced,
    );

    final out = timelineMessageSurfacesForDisplay([first, second]);

    expect(out.map((s) => s.eventId).toList(), [r'$first', r'$second']);
  });

  test('timelineMessagesForDisplay filters unsynced local echo Event', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: 'tx-local',
      senderId: '@me:example.org',
      body: '当前我有哪些订阅?',
      originServerTsMs: 100000,
      status: EventStatus.sent,
    );
    final synced = _messageEvent(
      room: room,
      eventId: r'$server',
      senderId: '@me:example.org',
      body: '当前我有哪些订阅?',
      originServerTsMs: 101000,
      status: EventStatus.synced,
    );

    final out = timelineMessagesForDisplay([localEcho, synced]);

    expect(out.map((e) => e.eventId).toList(), [r'$server']);
  });

  test('timelineMessagesForDisplay filters own sending local echo Event', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: 'tx-local-sending',
      senderId: '@me:example.org',
      body: '我在输入中',
      originServerTsMs: 100000,
      status: EventStatus.sending,
    );

    final out = timelineMessagesForDisplay([localEcho]);

    expect(out, isEmpty);
  });

  test('timelineMessagesForDisplay filters own error local echo Event', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: 'tx-local-error',
      senderId: '@me:example.org',
      body: '发送失败',
      originServerTsMs: 100000,
      status: EventStatus.error,
    );

    final out = timelineMessagesForDisplay([localEcho]);

    expect(out, isEmpty);
  });

  test('timelineMessagesForDisplay keeps unsynced event from other user', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final remoteLocalEchoLike = _messageEvent(
      room: room,
      eventId: 'other-unsynced',
      senderId: '@other:example.org',
      body: '对方未回执消息',
      originServerTsMs: 100000,
      status: EventStatus.sending,
    );

    final out = timelineMessagesForDisplay([remoteLocalEchoLike]);

    expect(out.map((e) => e.eventId).toList(), ['other-unsynced']);
  });

  test('timelineMessagesForDisplay hides persisted own sent local echo', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final localEcho = _messageEvent(
      room: room,
      eventId: r'$server',
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 100000,
      status: EventStatus.sent,
      transactionId: 'tx-local',
    );

    final out = timelineMessagesForDisplay([localEcho]);

    expect(out, isEmpty);
  });

  test('timelineMessagesForDisplay keeps synced own event', () {
    final client = Client('test-client', database: _FakeDatabase());
    client.setUserId('@me:example.org');
    final room = Room(id: '!room:example.org', client: client);
    final synced = _messageEvent(
      room: room,
      eventId: r'$server',
      senderId: '@me:example.org',
      body: '你好',
      originServerTsMs: 100000,
      status: EventStatus.synced,
      transactionId: 'tx-local',
    );

    final out = timelineMessagesForDisplay([synced]);

    expect(out, [synced]);
  });
}
