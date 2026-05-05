import 'package:matrix/matrix.dart';

import '../matrix/timeline_messages.dart';
import 'realtime_secretary_models.dart';

Future<List<SecretaryTextBubble>> loadRecentRoomTextBubbles({
  required Room room,
  required int limit,
}) async {
  final timeline = await room.getTimeline();
  try {
    final events = timelineMessagesForDisplay(timeline.events)
        .where(
          (event) =>
              event.type == EventTypes.Message &&
              event.messageType == MessageTypes.Text &&
              event.body.trim().isNotEmpty,
        )
        .take(limit)
        .toList(growable: false)
        .reversed;
    return events
        .map(
          (event) => SecretaryTextBubble(
            senderName: _senderName(event.senderId, room),
            body: event.body,
          ),
        )
        .toList(growable: false);
  } finally {
    timeline.cancelSubscriptions();
  }
}

String _senderName(String? senderId, Room room) {
  if (senderId == null || senderId.isEmpty) return '未知';
  try {
    final user = room.unsafeGetUserFromMemoryOrFallback(senderId);
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
  } catch (_) {}
  return senderId.split(':').first.replaceFirst('@', '');
}
