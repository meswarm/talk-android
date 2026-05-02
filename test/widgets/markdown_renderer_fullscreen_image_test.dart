import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:talk/pages/fullscreen_image_viewer_page.dart';
import 'package:talk/r2/r2_service.dart';
import 'package:talk/widgets/markdown_renderer.dart';

/// 与 `r2_markdown_image_fullscreen_test.dart` 相同的 1×1 PNG。
const List<int> _kTinyPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

/// [NetworkImage] 通过 `HttpClient()` 走 [HttpOverrides]；本类在 [HttpOverrides.runZoned] 内提供 200 + PNG 的 [getUrl] 响应。
class _PngHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _PngHttpClient();
}

class _PngHttpClient extends Fake implements HttpClient {
  final _PngHttpClientRequest request = _PngHttpClientRequest();

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => request;
}

class _PngHttpClientRequest extends Fake implements HttpClientRequest {
  final _PngHttpClientResponse response = _PngHttpClientResponse();

  @override
  HttpHeaders get headers => _PngHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => response;
}

class _PngHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _kTinyPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[
      Uint8List.fromList(_kTinyPng),
    ]).listen(onData, onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  @override
  Future<E> drain<E>([E? futureValue]) async {
    return futureValue as E;
  }
}

class _PngHttpHeaders extends Fake implements HttpHeaders {}

Finder _markdownImageTapTarget() {
  return find.descendant(
    of: find.byType(MarkdownRenderer),
    matching: find.byWidgetPredicate(
      (w) => w is GestureDetector && w.behavior == HitTestBehavior.opaque,
    ),
  );
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  testWidgets('tapping network markdown image opens fullscreen viewer',
      (tester) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<R2Service>(
          create: (_) => R2Service(),
          child: const MaterialApp(
            home: Scaffold(
              body: MarkdownRenderer(
                data: '![x](https://example.com/a.png)',
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_markdownImageTapTarget().first);
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
    }, createHttpClient: _PngHttpOverrides().createHttpClient);
  });

  testWidgets('tapping asset markdown image opens fullscreen viewer',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<R2Service>(
        create: (_) => R2Service(),
        child: const MaterialApp(
          home: Scaffold(
            body: MarkdownRenderer(
              data: '![x](assets/test/1x1.png)',
              isDark: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_markdownImageTapTarget().first);
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
  });
}
