class RoomActivity {
  final String roomId;
  final int lastTsMs;

  const RoomActivity({required this.roomId, required this.lastTsMs});
}

List<RoomActivity> sortRoomsByActivity(List<RoomActivity> rooms) {
  final out = List<RoomActivity>.from(rooms);
  out.sort((a, b) => b.lastTsMs.compareTo(a.lastTsMs));
  return out;
}

List<RoomActivity> sortRoomsWithPins(
  List<RoomActivity> rooms,
  List<String> pinnedIdsOrdered,
) {
  final byId = {for (final r in rooms) r.roomId: r};
  final pinned = <RoomActivity>[];
  final seen = <String>{};

  for (final id in pinnedIdsOrdered) {
    final r = byId[id];
    if (r != null && !seen.contains(id)) {
      pinned.add(r);
      seen.add(id);
    }
  }

  final rest = rooms.where((r) => !seen.contains(r.roomId)).toList();
  return [...pinned, ...sortRoomsByActivity(rest)];
}
