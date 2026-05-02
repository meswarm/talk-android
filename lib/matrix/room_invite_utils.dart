import 'package:matrix/matrix.dart';

/// Minimal port of `talkweb/src/matrix/roomUtils.ts` `getRoomInviteInviterId`.
String? getRoomInviteInviterId(Room room) {
  if (room.membership != Membership.invite) return null;
  final me = room.client.userID;
  if (me == null) return null;
  final ev = room.getState(EventTypes.RoomMember, me);
  if (ev == null) return null;

  // Mirrors `matrix-js-sdk` `RoomMember.getDMInviter()` for pending invites:
  // when `is_direct` is set on the invite member event, the inviter is the
  // event sender (not necessarily inferable from other heuristics).
  final content = ev.content;
  if (content.tryGet<String>('membership') == 'invite' &&
      content['is_direct'] == true) {
    return ev.senderId;
  }

  return ev.senderId;
}
