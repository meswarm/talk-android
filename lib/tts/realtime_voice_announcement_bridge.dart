import 'package:flutter/services.dart';

import 'doubao_tts_models.dart';

abstract class RealtimeVoiceAnnouncementBridge {
  Future<void> speakTextQuery({
    required DoubaoTtsConfig config,
    required String text,
  });
}

class MethodChannelRealtimeVoiceAnnouncementBridge
    implements RealtimeVoiceAnnouncementBridge {
  const MethodChannelRealtimeVoiceAnnouncementBridge({
    MethodChannel channel = const MethodChannel('talk/realtime_secretary'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> speakTextQuery({
    required DoubaoTtsConfig config,
    required String text,
  }) async {
    try {
      await _channel.invokeMethod<void>('speakVoiceAnnouncementTextQuery', {
        'appId': config.realtimeAppId,
        'appKey': config.realtimeAppKey,
        'accessToken': config.realtimeAccessToken,
        'resourceId': config.realtimeResourceId,
        'secretaryName': '小智',
        'model': config.realtimeModel,
        'speaker': config.realtimeSpeaker,
        'systemRole': config.realtimeSystemRole,
        'speakingStyle': config.realtimeSpeakingStyle,
        'inputMode': 'text',
        'speechRate': config.speechRate,
        'loudnessRate': config.loudnessRate,
        'text': text,
      });
    } on MissingPluginException {
      return;
    }
  }
}
