import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/pages/fullscreen_image_viewer_page.dart';
import 'package:talk/r2/r2_models.dart';
import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/r2_markdown_image.dart';

/// 1×1 PNG，等价于旧版 `flutter_test` 的 `kTransparentImage`（较新 SDK 已移除该常量）。
const List<int> _kTinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _TestR2 extends R2Service {
  @override
  Future<Uint8List> fetchRefBytes(String ref) async {
    return Uint8List.fromList(_kTinyPng);
  }
}

void main() {
  late _TestR2 r2;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'write':
        case 'delete':
        case 'read':
        case 'readAll':
        case 'deleteAll':
          return null;
        default:
          return null;
      }
    });
  });

  setUp(() async {
    r2 = _TestR2();
    await r2.saveCredentials(
      const R2SecretPayload(
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
        accountId: 'acct',
        defaultBucket: 'bucket',
        region: 'auto',
      ),
    );
  });

  tearDown(() async {
    await r2.forgetCredentials();
  });

  testWidgets('tapping R2 markdown image opens fullscreen viewer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: R2MarkdownImage(
            r2: r2,
            ref: 'r2://bucket/x.png',
            isDark: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = find.descendant(
      of: find.byType(R2MarkdownImage),
      matching: find.byType(Image),
    );
    await tester.ensureVisible(image);
    await tester.pumpAndSettle();
    await tester.tap(image, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
  });
}
