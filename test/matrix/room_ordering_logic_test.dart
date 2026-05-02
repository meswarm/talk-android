import 'package:flutter_test/flutter_test.dart';
import 'package:talk/matrix/room_ordering_logic.dart';

void main() {
  test('pinned ids keep order and exclude missing rooms', () {
    final rooms = <RoomActivity>[
      RoomActivity(roomId: '!a:hs', lastTsMs: 10),
      RoomActivity(roomId: '!b:hs', lastTsMs: 200),
      RoomActivity(roomId: '!c:hs', lastTsMs: 150),
    ];

    final ordered = sortRoomsWithPins(
      rooms,
      const ['!missing:hs', '!c:hs', '!a:hs'],
    );

    expect(ordered.map((r) => r.roomId).toList(), ['!c:hs', '!a:hs', '!b:hs']);
  });
}
