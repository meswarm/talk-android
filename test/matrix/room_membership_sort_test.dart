import 'package:flutter_test/flutter_test.dart';
import 'package:talk/matrix/room_ordering_logic.dart';

void main() {
  group('sortRoomsByActivity (lastTsMs desc, parity with MatrixService.rooms)', () {
    test('orders by recency descending', () {
      final ordered = sortRoomsByActivity(const [
        RoomActivity(roomId: '!old:hs', lastTsMs: 100),
        RoomActivity(roomId: '!new:hs', lastTsMs: 500),
        RoomActivity(roomId: '!mid:hs', lastTsMs: 300),
      ]);

      expect(
        ordered.map((e) => e.roomId).toList(),
        ['!new:hs', '!mid:hs', '!old:hs'],
      );
    });

    test('equal timestamps still returns both rooms', () {
      final ordered = sortRoomsByActivity(const [
        RoomActivity(roomId: '!a:hs', lastTsMs: 10),
        RoomActivity(roomId: '!b:hs', lastTsMs: 10),
      ]);

      expect(ordered.length, 2);
      expect(
        ordered.map((e) => e.roomId).toSet(),
        {'!a:hs', '!b:hs'},
      );
    });
  });

  group('sortRoomsWithPins (joined list with Task1/2 ordering)', () {
    test('pins precede unpinned, both groups by activity desc', () {
      final rooms = <RoomActivity>[
        RoomActivity(roomId: '!p1:hs', lastTsMs: 50),
        RoomActivity(roomId: '!u1:hs', lastTsMs: 900),
        RoomActivity(roomId: '!p2:hs', lastTsMs: 200),
        RoomActivity(roomId: '!u2:hs', lastTsMs: 100),
      ];

      final ordered = sortRoomsWithPins(rooms, const ['!p2:hs', '!p1:hs']);

      expect(ordered.map((r) => r.roomId).toList(), [
        '!p2:hs',
        '!p1:hs',
        '!u1:hs',
        '!u2:hs',
      ]);
    });
  });
}
