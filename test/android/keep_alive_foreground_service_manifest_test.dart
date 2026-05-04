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
      contains(
        'android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING',
      ),
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
}
