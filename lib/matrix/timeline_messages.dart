import 'package:matrix/matrix.dart';

/// Pure-data view of the fields `talkweb/src/matrix/roomUtils.ts` uses to
/// filter/dedupe timeline rows (keeps unit tests independent of sqlite/db).
class TimelineMessageSurface {
  final String type;
  final String? relationshipType;
  final String eventId;
  final String? transactionId;
  final String senderId;
  final String body;
  final int originServerTsMs;
  final EventStatus status;

  const TimelineMessageSurface({
    required this.type,
    required this.relationshipType,
    required this.eventId,
    required this.transactionId,
    this.senderId = '',
    this.body = '',
    this.originServerTsMs = 0,
    this.status = EventStatus.synced,
  });

  bool get isRenderable {
    if (type != EventTypes.Message && type != EventTypes.Sticker) {
      return false;
    }
    if (relationshipType == RelationshipTypes.edit) return false;
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is TimelineMessageSurface &&
        other.type == type &&
        other.relationshipType == relationshipType &&
        other.eventId == eventId &&
        other.transactionId == transactionId &&
        other.senderId == senderId &&
        other.body == body &&
        other.originServerTsMs == originServerTsMs &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
    type,
    relationshipType,
    eventId,
    transactionId,
    senderId,
    body,
    originServerTsMs,
    status,
  );
}

TimelineMessageSurface timelineMessageSurfaceFromEvent(Event e) {
  return TimelineMessageSurface(
    type: e.type,
    relationshipType: e.relationshipType,
    eventId: e.eventId,
    transactionId: e.transactionId,
    senderId: e.senderId,
    body: e.body,
    originServerTsMs: e.originServerTs.millisecondsSinceEpoch,
    status: e.status,
  );
}

const int _kLocalEchoDuplicateWindowMs = 2 * 60 * 1000;

String _surfaceBodyFingerprint(TimelineMessageSurface s) =>
    '${s.type}\u0000${s.senderId}\u0000${s.body}';

bool _looksLikeLocalEchoDuplicate(
  TimelineMessageSurface candidate,
  TimelineMessageSurface synced,
) {
  if (candidate.status.isSynced || !synced.status.isSynced) return false;
  if (candidate.senderId.isEmpty || candidate.body.isEmpty) return false;
  if (_surfaceBodyFingerprint(candidate) != _surfaceBodyFingerprint(synced)) {
    return false;
  }
  final delta = (candidate.originServerTsMs - synced.originServerTsMs).abs();
  return delta <= _kLocalEchoDuplicateWindowMs;
}

/// Port of `talkweb/src/matrix/roomUtils.ts` `timelineMessagesForDisplay` core.
///
/// Preserves input order while removing duplicate event IDs and duplicate
/// local-echo lines that share the same Matrix `unsigned.transaction_id`.
List<TimelineMessageSurface> timelineMessageSurfacesForDisplay(
  Iterable<TimelineMessageSurface> surfaces,
) {
  final msgs = surfaces.where((s) => s.isRenderable).toList();

  final seenId = <String>{};
  final byId = <TimelineMessageSurface>[];
  for (final s in msgs) {
    final id = s.eventId;
    if (id.isNotEmpty) {
      if (seenId.contains(id)) continue;
      seenId.add(id);
    }
    byId.add(s);
  }

  final txnLastIdx = <String, int>{};
  for (var i = 0; i < byId.length; i++) {
    final txn = byId[i].transactionId;
    if (txn != null && txn.isNotEmpty) {
      txnLastIdx[txn] = i;
    }
  }

  final out = <TimelineMessageSurface>[];
  for (var i = 0; i < byId.length; i++) {
    final txn = byId[i].transactionId;
    if (txn != null && txn.isNotEmpty && txnLastIdx[txn] != i) continue;
    out.add(byId[i]);
  }

  final syncedByBody = <String, List<TimelineMessageSurface>>{};
  for (final s in out) {
    if (!s.status.isSynced || s.senderId.isEmpty || s.body.isEmpty) continue;
    syncedByBody.putIfAbsent(_surfaceBodyFingerprint(s), () => []).add(s);
  }

  return [
    for (final s in out)
      if (!(syncedByBody[_surfaceBodyFingerprint(s)] ?? const []).any(
        (synced) => _looksLikeLocalEchoDuplicate(s, synced),
      ))
        s,
  ];
}

/// Port of `talkweb/src/matrix/roomUtils.ts` `timelineMessagesForDisplay`.
List<Event> timelineMessagesForDisplay(Iterable<Event> events) {
  final list = events.where((e) => !_isOwnUnSyncedLocalEcho(e)).toList();
  final surfaces = list.map(timelineMessageSurfaceFromEvent).toList();

  final renderable = <({int idx, TimelineMessageSurface surface})>[];
  for (var i = 0; i < surfaces.length; i++) {
    final s = surfaces[i];
    if (!s.isRenderable) continue;
    renderable.add((idx: i, surface: s));
  }

  final seenId = <String>{};
  final byId = <({int idx, TimelineMessageSurface surface})>[];
  for (final row in renderable) {
    final id = row.surface.eventId;
    if (id.isNotEmpty) {
      if (seenId.contains(id)) continue;
      seenId.add(id);
    }
    byId.add(row);
  }

  final txnLastIdx = <String, int>{};
  for (var i = 0; i < byId.length; i++) {
    final txn = byId[i].surface.transactionId;
    if (txn != null && txn.isNotEmpty) {
      txnLastIdx[txn] = i;
    }
  }

  final out = <({int idx, TimelineMessageSurface surface})>[];
  for (var i = 0; i < byId.length; i++) {
    final txn = byId[i].surface.transactionId;
    if (txn != null && txn.isNotEmpty && txnLastIdx[txn] != i) continue;
    out.add(byId[i]);
  }

  final syncedByBody = <String, List<TimelineMessageSurface>>{};
  for (final row in out) {
    final s = row.surface;
    if (!s.status.isSynced || s.senderId.isEmpty || s.body.isEmpty) continue;
    syncedByBody.putIfAbsent(_surfaceBodyFingerprint(s), () => []).add(s);
  }

  return [
    for (final row in out)
      if (!(syncedByBody[_surfaceBodyFingerprint(row.surface)] ?? const []).any(
        (synced) => _looksLikeLocalEchoDuplicate(row.surface, synced),
      ))
        list[row.idx],
  ];
}

bool _isOwnUnSyncedLocalEcho(Event event) {
  final ownUserId = event.room.client.userID;
  return !event.status.isSynced &&
      ownUserId != null &&
      ownUserId.isNotEmpty &&
      event.senderId == ownUserId;
}
