import 'package:matrix/matrix.dart';

/// Pure formatter mirroring `talkweb` `buildTypingLine` / `useRoomTyping.ts`.
String? buildTypingLineFromNames(List<String> names) {
  if (names.isEmpty) return null;
  if (names.length == 1) return '${names[0]} 正在输入…';
  if (names.length == 2) return '${names[0]}、${names[1]} 正在输入…';
  return '${names[0]}、${names[1]} 等 ${names.length} 人正在输入…';
}

String _typingUserLabel(User user) {
  final raw = user.calcDisplayname().trim();
  if (raw.isNotEmpty) return raw;
  return user.id.localpart ?? user.id;
}

/// Remote typing line for the room, excluding self, same Chinese patterns as web.
String? buildRemoteTypingLine(Room room) {
  final my = room.client.userID;
  final typists = room.typingUsers
      .where(
        (u) =>
            (my == null || u.id != my) && u.membership == Membership.join,
      )
      .toList();
  if (typists.isEmpty) return null;
  final names = typists.map(_typingUserLabel).toList();
  return buildTypingLineFromNames(names);
}
