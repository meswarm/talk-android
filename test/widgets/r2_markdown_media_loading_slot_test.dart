import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/r2/r2_models.dart';
import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/r2_markdown_image.dart';
import 'package:talk/widgets/r2_markdown_video.dart';

const _tinyPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _PendingR2 extends R2Service {
  final image = Completer<Uint8List>();
  final video = Completer<String>();

  @override
  Future<Uint8List> fetchRefBytes(String ref) => image.future;

  @override
  Future<String> fetchRefFile(String ref) => video.future;
}

class _ImmediateImageR2 extends R2Service {
  @override
  Future<Uint8List> fetchRefBytes(String ref) async {
    return Uint8List.fromList(_tinyPng);
  }
}

void main() {
  late _PendingR2 r2;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
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
    r2 = _PendingR2();
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

  testWidgets('R2 image loading state reserves the configured preview slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: R2MarkdownImage(
            r2: r2,
            ref: 'r2://bucket/table-image.png',
            isDark: false,
            maxImageWidth: 96,
            maxImageHeight: 72,
          ),
        ),
      ),
    );

    expect(_findSlot(width: 96, height: 72), findsOneWidget);
    expect(_findSlot(width: 120, height: 80), findsNothing);
  });

  testWidgets('R2 image fills the reserved preview slot after loading', (
    tester,
  ) async {
    final imageR2 = _ImmediateImageR2();
    await imageR2.saveCredentials(
      const R2SecretPayload(
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
        accountId: 'acct',
        defaultBucket: 'bucket',
        region: 'auto',
      ),
    );
    addTearDown(imageR2.forgetCredentials);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: R2MarkdownImage(
            r2: imageR2,
            ref: 'r2://bucket/table-image.png',
            isDark: false,
            maxImageWidth: 96,
            maxImageHeight: 72,
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(R2MarkdownImage),
        matching: find.byType(Image),
      ),
    );
    expect(image.width, 96);
    expect(image.height, 72);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('R2 video loading state reserves the configured preview slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: R2MarkdownVideo(
            r2: r2,
            ref: 'r2://bucket/table-video.mp4',
            isDark: false,
            maxImageWidth: 96,
            maxImageHeight: 72,
          ),
        ),
      ),
    );

    expect(_findSlot(width: 96, height: 72), findsOneWidget);
    expect(_findSlot(width: 120, height: 80), findsNothing);
  });
}

Finder _findSlot({required double width, required double height}) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is SizedBox && widget.width == width && widget.height == height,
  );
}
