import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:talk/matrix/room_ordering_logic.dart';

import '../services/local_storage.dart';
import '../services/matrix_service.dart';

List<Room> _roomsSortedByLastEvent(Iterable<Room> source) {
  final list = source.toList();
  final activities = list
      .map(
        (room) => RoomActivity(
          roomId: room.id,
          lastTsMs:
              room.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0,
        ),
      )
      .toList();
  final sortedActs = sortRoomsByActivity(activities);
  final byId = {for (final r in list) r.id: r};
  return sortedActs.map((a) => byId[a.roomId]!).toList();
}

class ChatProvider extends ChangeNotifier {
  final MatrixService matrixService;

  ChatProvider({required this.matrixService});

  List<String> _pinnedRoomIds = [];

  /// 开始监听同步事件
  void startListening() {
    LocalStorage().loadPinnedRoomIds().then((ids) {
      _pinnedRoomIds = ids;
      notifyListeners();
    });
    matrixService.client.onSync.stream.listen((_) {
      notifyListeners();
    });
  }

  /// 仅已加入房间，应用置顶规则（与 [joinedRoomsPinnedSorted] 相同）。
  List<Room> get rooms => joinedRoomsPinnedSorted;

  List<Room> get invitedRooms {
    final invites = matrixService.client.rooms
        .where((r) => r.membership == Membership.invite);
    return _roomsSortedByLastEvent(invites);
  }

  List<Room> get joinedRoomsPinnedSorted {
    final joined = matrixService.client.rooms
        .where((r) => r.membership == Membership.join);
    final base = _roomsSortedByLastEvent(joined);
    if (_pinnedRoomIds.isEmpty) {
      return base;
    }
    final activities = base
        .map(
          (room) => RoomActivity(
            roomId: room.id,
            lastTsMs:
                room.lastEvent?.originServerTs.millisecondsSinceEpoch ?? 0,
          ),
        )
        .toList();
    final ordered = sortRoomsWithPins(activities, _pinnedRoomIds);
    final byId = {for (final r in base) r.id: r};
    return ordered.map((a) => byId[a.roomId]!).toList();
  }

  bool isRoomPinned(String roomId) => _pinnedRoomIds.contains(roomId);

  Future<void> pinRoom(String roomId) async {
    if (_pinnedRoomIds.contains(roomId)) return;
    _pinnedRoomIds = [..._pinnedRoomIds, roomId];
    await LocalStorage().savePinnedRoomIds(_pinnedRoomIds);
    notifyListeners();
  }

  Future<void> unpinRoom(String roomId) async {
    if (!_pinnedRoomIds.contains(roomId)) return;
    _pinnedRoomIds =
        _pinnedRoomIds.where((id) => id != roomId).toList(growable: false);
    await LocalStorage().savePinnedRoomIds(_pinnedRoomIds);
    notifyListeners();
  }

  Future<void> reloadPinnedRoomIds() async {
    _pinnedRoomIds = await LocalStorage().loadPinnedRoomIds();
    notifyListeners();
  }

  String getRoomDisplayName(Room room) =>
      matrixService.getRoomDisplayName(room);

  String getLastMessagePreview(Room room) =>
      matrixService.getLastMessagePreview(room);
}
