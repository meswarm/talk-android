import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:talk/room/room_r2_prefix.dart';

void main() {
  group('validateRoomR2Prefix', () {
    test('accepts single segment', () {
      final r = validateRoomR2Prefix('  A-room  ');
      expect(r, isA<RoomR2PrefixOk>());
      expect((r as RoomR2PrefixOk).normalized, 'A-room');
    });

    test('accepts multi-level path', () {
      final r = validateRoomR2Prefix('team-a/A-room');
      expect(r, isA<RoomR2PrefixOk>());
      expect((r as RoomR2PrefixOk).normalized, 'team-a/A-room');
    });

    test('empty after trim is not configured', () {
      final r = validateRoomR2Prefix('   ');
      expect(r, isA<RoomR2PrefixNotConfigured>());
    });

    test('rejects leading slash', () {
      final r = validateRoomR2Prefix('/a');
      expect(r, isA<RoomR2PrefixInvalid>());
    });

    test('rejects empty segment', () {
      final r = validateRoomR2Prefix('a//b');
      expect(r, isA<RoomR2PrefixInvalid>());
    });

    test('rejects dot segments', () {
      expect(validateRoomR2Prefix('..'), isA<RoomR2PrefixInvalid>());
      expect(validateRoomR2Prefix('a/..'), isA<RoomR2PrefixInvalid>());
    });

    test('rejects backslash', () {
      expect(validateRoomR2Prefix(r'a\b'), isA<RoomR2PrefixInvalid>());
    });
  });

  group('parseRoomR2PrefixFromState', () {
    test('parses ok from StrippedStateEvent', () {
      final ev = StrippedStateEvent.fromJson({
        'type': kTalkRoomR2PrefixEventType,
        'state_key': '',
        'sender': '@u:localhost',
        'content': {'prefix': 'p/imgs'},
      });
      final r = parseRoomR2PrefixFromState(ev);
      expect(r, isA<RoomR2PrefixOk>());
      expect((r as RoomR2PrefixOk).normalized, 'p/imgs');
    });

    test('null state is not configured', () {
      expect(parseRoomR2PrefixFromState(null), isA<RoomR2PrefixNotConfigured>());
    });

    test('invalid content yields invalid', () {
      final ev = StrippedStateEvent.fromJson({
        'type': kTalkRoomR2PrefixEventType,
        'state_key': '',
        'sender': '@u:localhost',
        'content': {'prefix': '/bad'},
      });
      expect(parseRoomR2PrefixFromState(ev), isA<RoomR2PrefixInvalid>());
    });
  });
}
