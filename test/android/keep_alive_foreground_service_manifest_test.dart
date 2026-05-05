import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keep alive foreground service declares Android 14 service type', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/example/talk/TalkKeepAliveService.kt',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING'),
    );
    expect(
      manifest,
      contains('android:foregroundServiceType="remoteMessaging"'),
    );
    expect(
      service,
      contains('ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING'),
    );
  });

  test(
    'realtime secretary declares microphone foreground service and sdk deps',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final service = File(
        'android/app/src/main/kotlin/com/example/talk/TalkRealtimeSecretaryService.kt',
      ).readAsStringSync();
      final rootGradle = File('android/build.gradle.kts').readAsStringSync();
      final appGradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'),
      );
      expect(manifest, contains('android:foregroundServiceType="microphone"'));
      expect(
        service,
        contains('ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE'),
      );
      expect(service, contains('PARAMS_KEY_AUDIO_STREAM_TYPE_INT'));
      expect(service, contains('AUDIO_STREAM_TYPE_MEDIA'));
      expect(service, contains('JSONObject().put("content"'));
      expect(service, contains('PrepareEnvironment'));
      expect(service, contains('PARAMS_KEY_UID_STRING'));
      expect(service, contains('PARAMS_KEY_RECORDER_TYPE_STRING'));
      expect(service, contains('RECORDER_TYPE_RECORDER'));
      expect(service, contains('PARAMS_KEY_DIALOG_RECORDER_PATH_STRING'));
      expect(
        service,
        contains('PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL'),
      );
      expect(
        service,
        contains('PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL'),
      );
      expect(
        service,
        contains('PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL'),
      );
      expect(service, contains('PARAMS_KEY_DIALOG_PLAYER_PATH_STRING'));
      expect(service, contains('DIRECTIVE_SYNC_STOP_ENGINE'));
      expect(service, contains('DIRECTIVE_START_ENGINE'));
      expect(service, contains('"bot_name"'));
      expect(service, contains('"system_role"'));
      expect(service, contains('"speaking_style"'));
      expect(service, contains('"input_mod"'));
      expect(service, contains('"text"'));
      expect(service, contains('"dialog_context"'));
      expect(service, contains('"model"'));
      expect(service, contains('"tts"'));
      expect(service, contains('"speaker"'));
      expect(service, contains('"speech_rate"'));
      expect(service, contains('"loudness_rate"'));
      expect(service, contains('testConfig requested'));
      expect(service, contains('sending DIRECTIVE_EVENT_SAY_HELLO'));
      expect(service, contains('testSessionDurationMs = 10000L'));
      expect(service, isNot(contains('voiceAnnouncementSessionDurationMs')));
      expect(service, contains('voiceAnnouncementSafetyTimeoutMs = 60000L'));
      expect(service, contains('voiceAnnouncementAudioIdleStopMs = 1500L'));
      expect(service, contains('scheduleVoiceAnnouncementAudioIdleStop(len)'));
      expect(service, contains('"inputMode" to "text"'));
      expect(
        service,
        contains(
          'PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL,\n'
          '                true',
        ),
      );
      expect(
        service,
        contains(
          'PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL,\n'
          '                true',
        ),
      );
      expect(service, contains('MESSAGE_TYPE_PLAYER_AUDIO_DATA'));
      expect(service, contains('MESSAGE_TYPE_DECODER_AUDIO_DATA'));
      expect(service, contains('MESSAGE_TYPE_DIALOG_ASR_INFO ->'));
      expect(service, contains('MESSAGE_TYPE_DIALOG_ASR_ENDED ->'));
      expect(service, contains('onRealtimeSecretarySpeechStarted'));
      expect(service, contains('onRealtimeSecretarySpeechEnded'));
      expect(service, contains('extractAsrText(raw)'));
      expect(service, contains('Regex("[\\\\u4E00-\\\\u9FFF'));
      expect(service, contains('MESSAGE_TYPE_ENGINE_STOP ->'));
      expect(service, contains('MESSAGE_TYPE_DIALOG_SESSION_FINISHED ->'));
      expect(service, contains('MESSAGE_TYPE_DIALOG_SESSION_FAILED ->'));
      expect(service, contains('onRealtimeSecretarySessionEnded'));
      expect(service, contains('PARAMS_KEY_ENABLE_AEC_BOOL'));
      expect(
        service,
        isNot(contains('PARAMS_KEY_ENABLE_AEC_BOOL,\n                true')),
      );
      expect(
        rootGradle,
        contains('artifact.bytedance.com/repository/Volcengine'),
      );
      expect(
        appGradle,
        contains('com.bytedance.speechengine:speechengine_tob:0.0.14.6'),
      );
      expect(appGradle, contains('com.squareup.okhttp3:okhttp'));
    },
  );
}
