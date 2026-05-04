class FcmPushPayload {
  const FcmPushPayload({
    required this.title,
    required this.body,
    required this.roomId,
    required this.eventId,
    required this.senderName,
  });

  final String title;
  final String body;
  final String? roomId;
  final String? eventId;
  final String? senderName;

  bool get hasRoomTarget => roomId != null && roomId!.isNotEmpty;

  factory FcmPushPayload.fromParts({
    required String? notificationTitle,
    required String? notificationBody,
    required Map<String, dynamic> data,
  }) {
    String? clean(Object? raw) {
      final value = raw?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return FcmPushPayload(
      title: clean(notificationTitle) ?? 'Talk',
      body: clean(notificationBody) ?? '你有一条新消息',
      roomId: clean(data['roomId']),
      eventId: clean(data['eventId']),
      senderName: clean(data['senderName']),
    );
  }

  String? get notificationPayload => hasRoomTarget ? roomId : null;
}
