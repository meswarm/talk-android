import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:talk/pages/camera_capture_page.dart';

void main() {
  test('maxVideoDuration is 15 seconds', () {
    expect(CameraCapturePage.maxVideoDuration, const Duration(seconds: 15));
  });

  testWidgets('shows no-camera message when camera list is empty and permission granted',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      MaterialApp(
        home: CameraCapturePage(
          cameraListProvider: () async => <CameraDescription>[],
          requestCameraPermission: () async => PermissionStatus.granted,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('没有可用相机'), findsOneWidget);
  });

  testWidgets('shows permission-denied message when camera permission denied',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await tester.pumpWidget(
      MaterialApp(
        home: CameraCapturePage(
          cameraListProvider: () async => <CameraDescription>[],
          requestCameraPermission: () async => PermissionStatus.denied,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('需要相机权限'), findsOneWidget);
  });
}
