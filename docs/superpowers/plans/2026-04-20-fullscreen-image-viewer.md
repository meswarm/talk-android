# Fullscreen Image Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable fullscreen image viewer for chat images that opens from message attachments and Markdown images, defaults to full-image display, and supports toolbar toggling, double-tap zoom, pinch zoom, pan, and fit-screen / fit-width modes.

**Architecture:** Build one dedicated fullscreen page backed by a small normalized image-source model and a single route helper. Keep the first version dependency-light by using Flutter's built-in `InteractiveViewer` and a shared `TransformationController`, then adapt current image surfaces into that one viewer entry point.

**Tech Stack:** Flutter, Dart, existing chat/media widgets, `InteractiveViewer`, `TransformationController`, `flutter_test`

---

## File Structure

### Create

- `lib/pages/fullscreen_image_viewer_page.dart`
  - Hosts the immersive fullscreen layout, toolbar, gesture wiring, display-mode switching, loading/failure UI, and transform reset logic.
- `lib/widgets/fullscreen_image_surface.dart`
  - Focused widget that renders the normalized image source and exposes consistent loading/error behavior for memory, network, and asset images.
- `lib/widgets/fullscreen_image_viewer_route.dart`
  - Defines the normalized image-source model plus the shared `openFullscreenImageViewer(...)` helper used by attachment and Markdown image widgets.
- `test/pages/fullscreen_image_viewer_page_test.dart`
  - Verifies toolbar toggle, mode switching, and base viewer layout behavior.
- `test/widgets/fullscreen_image_viewer_route_test.dart`
  - Verifies the shared route helper and normalized source behavior from widget call sites.

### Modify

- `lib/widgets/event_media_content.dart`
  - Wrap attachment images in a tap target that opens the shared fullscreen route using in-memory bytes.
- `lib/widgets/r2_markdown_image.dart`
  - Wrap resolved R2 image bytes in the shared fullscreen route.
- `lib/widgets/markdown_renderer.dart`
  - Wrap network and asset Markdown images in the shared fullscreen route.

### Existing References To Read During Execution

- `lib/widgets/event_media_content.dart`
  - Current attachment image rendering and loading lifecycle.
- `lib/widgets/r2_markdown_image.dart`
  - Current R2 byte-loading flow and inline image frame usage.
- `lib/widgets/markdown_renderer.dart`
  - Current Markdown image branches for network and asset URLs.
- `test/widgets/composer/mobile_markdown_composer_test.dart`
  - Existing navigator-driven widget test style in this repo.

## Task 1: Create the normalized fullscreen route and source model

**Files:**
- Create: `lib/widgets/fullscreen_image_viewer_route.dart`
- Create: `test/widgets/fullscreen_image_viewer_route_test.dart`

- [ ] **Step 1: Write the failing route-helper tests**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/widgets/fullscreen_image_viewer_route.dart';

void main() {
  testWidgets('openFullscreenImageViewer pushes the viewer page for memory images',
      (tester) async {
    final bytes = Uint8List.fromList(const [0, 1, 2, 3]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              openFullscreenImageViewer(
                context,
                source: FullscreenImageSource.memory(
                  bytes: bytes,
                  heroTag: 'mem-1',
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
  });

  test('asset and network constructors preserve their fields', () {
    const asset = FullscreenImageSource.asset(
      assetName: 'assets/demo.png',
      heroTag: 'asset-1',
    );
    const net = FullscreenImageSource.network(
      url: 'https://example.com/demo.png',
      heroTag: 'net-1',
    );

    expect(asset.assetName, 'assets/demo.png');
    expect(asset.kind, FullscreenImageSourceKind.asset);
    expect(net.url, 'https://example.com/demo.png');
    expect(net.kind, FullscreenImageSourceKind.network);
  });
}
```

- [ ] **Step 2: Run the route-helper tests and verify they fail**

Run: `flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded`

Expected: FAIL because `FullscreenImageSource`, `openFullscreenImageViewer`, and `FullscreenImageViewerPage` do not exist yet.

- [ ] **Step 3: Add the normalized source model**

```dart
enum FullscreenImageSourceKind { memory, network, asset }

class FullscreenImageSource {
  const FullscreenImageSource.memory({
    required this.bytes,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.memory,
        url = null,
        assetName = null;

  const FullscreenImageSource.network({
    required this.url,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.network,
        bytes = null,
        assetName = null;

  const FullscreenImageSource.asset({
    required this.assetName,
    required this.heroTag,
  })  : kind = FullscreenImageSourceKind.asset,
        bytes = null,
        url = null;

  final FullscreenImageSourceKind kind;
  final Uint8List? bytes;
  final String? url;
  final String? assetName;
  final Object heroTag;
}
```

- [ ] **Step 4: Add the shared route helper**

```dart
Future<void> openFullscreenImageViewer(
  BuildContext context, {
  required FullscreenImageSource source,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => FullscreenImageViewerPage(source: source),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    ),
  );
}
```

- [ ] **Step 5: Re-run the route-helper tests**

Run: `flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded`

Expected: PASS once the route helper and constructors compile and the push succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/widgets/fullscreen_image_viewer_route.dart \
  test/widgets/fullscreen_image_viewer_route_test.dart
git commit -m "feat: add fullscreen image viewer route helper"
```

## Task 2: Build the fullscreen viewer page with layout, modes, and toolbar toggling

**Files:**
- Create: `lib/pages/fullscreen_image_viewer_page.dart`
- Create: `lib/widgets/fullscreen_image_surface.dart`
- Test: `test/pages/fullscreen_image_viewer_page_test.dart`

- [ ] **Step 1: Write the failing viewer-page tests**

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:talk/pages/fullscreen_image_viewer_page.dart';
import 'package:talk/widgets/fullscreen_image_viewer_route.dart';

void main() {
  Widget buildPage() {
    return MaterialApp(
      home: FullscreenImageViewerPage(
        source: FullscreenImageSource.memory(
          bytes: Uint8List.fromList(const [0, 1, 2, 3]),
          heroTag: 'img-1',
        ),
      ),
    );
  }

  testWidgets('single tap toggles toolbar visibility', (tester) async {
    await tester.pumpWidget(buildPage());

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('switching to fit-width updates the selected mode label',
      (tester) async {
    await tester.pumpWidget(buildPage());

    await tester.tap(find.text('适应屏幕'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('适应宽度').last);
    await tester.pumpAndSettle();

    expect(find.text('适应宽度'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the viewer-page tests and verify they fail**

Run: `flutter test test/pages/fullscreen_image_viewer_page_test.dart -r expanded`

Expected: FAIL because the fullscreen page, its toolbar, and mode-switching UI do not exist yet.

- [ ] **Step 3: Add the shared image surface widget with source-specific rendering**

```dart
class FullscreenImageSurface extends StatelessWidget {
  const FullscreenImageSurface({super.key, required this.source});

  final FullscreenImageSource source;

  @override
  Widget build(BuildContext context) {
    switch (source.kind) {
      case FullscreenImageSourceKind.memory:
        return Image.memory(source.bytes!, fit: BoxFit.contain);
      case FullscreenImageSourceKind.network:
        return Image.network(
          source.url!,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) => const _ViewerLoadError(),
        );
      case FullscreenImageSourceKind.asset:
        return Image.asset(
          source.assetName!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _ViewerLoadError(),
        );
    }
  }
}
```

- [ ] **Step 4: Add the fullscreen page scaffold, dark layout, and toolbar toggle**

```dart
enum FullscreenImageDisplayMode { fitScreen, fitWidth }

class FullscreenImageViewerPage extends StatefulWidget {
  const FullscreenImageViewerPage({super.key, required this.source});

  final FullscreenImageSource source;

  @override
  State<FullscreenImageViewerPage> createState() =>
      _FullscreenImageViewerPageState();
}

class _FullscreenImageViewerPageState extends State<FullscreenImageViewerPage> {
  final TransformationController _transform = TransformationController();
  bool _toolbarVisible = true;
  FullscreenImageDisplayMode _mode = FullscreenImageDisplayMode.fitScreen;

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
  }

  void _setMode(FullscreenImageDisplayMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _transform.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleToolbar,
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: widget.source.heroTag,
                      child: FullscreenImageSurface(source: widget.source),
                    ),
                  ),
                ),
              ),
            ),
            if (_toolbarVisible)
              _ViewerTopBar(
                mode: _mode,
                onBack: () => Navigator.of(context).maybePop(),
                onModeChanged: _setMode,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Add the mode menu labels and transform reset behavior**

```dart
PopupMenuButton<FullscreenImageDisplayMode>(
  initialValue: mode,
  onSelected: onModeChanged,
  itemBuilder: (context) => const [
    PopupMenuItem(
      value: FullscreenImageDisplayMode.fitScreen,
      child: Text('适应屏幕'),
    ),
    PopupMenuItem(
      value: FullscreenImageDisplayMode.fitWidth,
      child: Text('适应宽度'),
    ),
  ],
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      mode == FullscreenImageDisplayMode.fitScreen ? '适应屏幕' : '适应宽度',
      style: const TextStyle(color: Colors.white),
    ),
  ),
)
```

- [ ] **Step 6: Re-run the viewer-page tests**

Run: `flutter test test/pages/fullscreen_image_viewer_page_test.dart -r expanded`

Expected: PASS for toolbar visibility and display-mode label changes.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/pages/fullscreen_image_viewer_page.dart \
  lib/widgets/fullscreen_image_surface.dart \
  test/pages/fullscreen_image_viewer_page_test.dart
git commit -m "feat: add fullscreen image viewer page"
```

## Task 3: Add double-tap zoom and base-state reset behavior

**Files:**
- Modify: `lib/pages/fullscreen_image_viewer_page.dart`
- Test: `test/pages/fullscreen_image_viewer_page_test.dart`

- [ ] **Step 1: Add the failing double-tap and reset tests**

```dart
testWidgets('double tap zooms in from base scale', (tester) async {
  await tester.pumpWidget(buildPage());

  final viewer = find.byType(InteractiveViewer);
  await tester.tap(viewer);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(viewer);
  await tester.pumpAndSettle();

  final state = tester.state<_FullscreenImageViewerPageState>(
    find.byType(FullscreenImageViewerPage),
  );
  expect(state.transformController.value.getMaxScaleOnAxis(), greaterThan(1));
});

testWidgets('switching display mode resets the transform to identity',
    (tester) async {
  await tester.pumpWidget(buildPage());

  final state = tester.state<_FullscreenImageViewerPageState>(
    find.byType(FullscreenImageViewerPage),
  );
  state.transformController.value = Matrix4.diagonal3Values(2.2, 2.2, 1);
  await tester.pump();

  await tester.tap(find.text('适应屏幕'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('适应宽度').last);
  await tester.pumpAndSettle();

  expect(state.transformController.value, equals(Matrix4.identity()));
});
```

- [ ] **Step 2: Run the viewer-page tests and verify they fail**

Run: `flutter test test/pages/fullscreen_image_viewer_page_test.dart -r expanded`

Expected: FAIL because the page does not yet expose a double-tap zoom behavior or a testable transform controller getter.

- [ ] **Step 3: Expose the controller for test inspection and add double-tap handling**

```dart
TransformationController get transformController => _transform;

TapDownDetails? _lastTapDown;

void _handleDoubleTapDown(TapDownDetails details) {
  _lastTapDown = details;
}

void _handleDoubleTap() {
  final currentScale = _transform.value.getMaxScaleOnAxis();
  if (currentScale > 1.01) {
    _transform.value = Matrix4.identity();
    return;
  }

  final focal = _lastTapDown?.localPosition;
  if (focal == null) {
    _transform.value = Matrix4.diagonal3Values(2.2, 2.2, 1);
    return;
  }

  final zoom = 2.2;
  final dx = -focal.dx * (zoom - 1);
  final dy = -focal.dy * (zoom - 1);
  _transform.value = Matrix4.identity()
    ..translate(dx, dy)
    ..scale(zoom);
}
```

- [ ] **Step 4: Wire double-tap into the gesture layer without losing single-tap toolbar toggling**

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: _toggleToolbar,
  onDoubleTapDown: _handleDoubleTapDown,
  onDoubleTap: _handleDoubleTap,
  child: Center(
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      panEnabled: _transform.value.getMaxScaleOnAxis() > 1.0,
      child: Hero(
        tag: widget.source.heroTag,
        child: _buildModeAwareImage(),
      ),
    ),
  ),
)
```

- [ ] **Step 5: Re-run the viewer-page tests**

Run: `flutter test test/pages/fullscreen_image_viewer_page_test.dart -r expanded`

Expected: PASS for toolbar toggling, double-tap zoom, and transform reset checks.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/pages/fullscreen_image_viewer_page.dart \
  test/pages/fullscreen_image_viewer_page_test.dart
git commit -m "feat: add fullscreen image zoom interactions"
```

## Task 4: Integrate the shared viewer into attachment images and R2 Markdown images

**Files:**
- Modify: `lib/widgets/event_media_content.dart`
- Modify: `lib/widgets/r2_markdown_image.dart`
- Test: `test/widgets/fullscreen_image_viewer_route_test.dart`

- [ ] **Step 1: Add the failing integration tests for memory-backed image taps**

```dart
testWidgets('tapping an attachment image opens the fullscreen viewer',
    (tester) async {
  final event = makeImageEventForTest();

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: EventMediaContent(event: event))),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(Image));
  await tester.pumpAndSettle();

  expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
});

testWidgets('tapping an R2 markdown image opens the fullscreen viewer',
    (tester) async {
  final r2 = FakeR2Service(bytes: kTransparentImage);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: R2MarkdownImage(
          r2: r2,
          ref: 'r2://bucket/demo.png',
          isDark: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(Image));
  await tester.pumpAndSettle();

  expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
});
```

- [ ] **Step 2: Run the route/integration tests and verify they fail**

Run: `flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded`

Expected: FAIL because attachment images and R2 Markdown images are still passive `Image` widgets without tap-to-open behavior.

- [ ] **Step 3: Wrap attachment images with the shared viewer opener**

```dart
return ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxH),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        openFullscreenImageViewer(
          context,
          source: FullscreenImageSource.memory(
            bytes: f.bytes,
            heroTag: 'event-image-${widget.event.eventId}',
          ),
        );
      },
      child: Hero(
        tag: 'event-image-${widget.event.eventId}',
        child: Image.memory(
          f.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Text(
            '[图片加载失败]',
            style: TextStyle(color: subtext, fontSize: 13),
          ),
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 4: Wrap R2 Markdown images with the same opener**

```dart
return R2MarkdownCardShell(
  onDelete: widget.onDelete,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      openFullscreenImageViewer(
        context,
        source: FullscreenImageSource.memory(
          bytes: b,
          heroTag: 'r2-image-${widget.ref}',
        ),
      );
    },
    child: Hero(
      tag: 'r2-image-${widget.ref}',
      child: MarkdownImageFrame(
        isDark: widget.isDark,
        maxHeight: widget.maxImageHeight,
        maxWidth: widget.maxImageWidth ?? double.infinity,
        child: Image.memory(
          b,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, _, _) => Text(
            '[图片解码失败]',
            style: TextStyle(color: sub, fontSize: 13),
          ),
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 5: Re-run the route/integration tests**

Run: `flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded`

Expected: PASS for both attachment-image and R2-image navigation flows.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/widgets/event_media_content.dart \
  lib/widgets/r2_markdown_image.dart \
  test/widgets/fullscreen_image_viewer_route_test.dart
git commit -m "feat: open fullscreen viewer from memory images"
```

## Task 5: Integrate the shared viewer into network and asset Markdown images, then run full verification

**Files:**
- Modify: `lib/widgets/markdown_renderer.dart`
- Modify: `test/widgets/fullscreen_image_viewer_route_test.dart`

- [ ] **Step 1: Add the failing Markdown renderer tests**

```dart
testWidgets('tapping a network markdown image opens the fullscreen viewer',
    (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: MarkdownRenderer(
          data: '![demo](https://example.com/demo.png)',
          isDark: false,
        ),
      ),
    ),
  );

  await tester.tap(find.byType(Image).first);
  await tester.pumpAndSettle();

  expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
});

testWidgets('tapping an asset markdown image opens the fullscreen viewer',
    (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: MarkdownRenderer(
          data: '![demo](assets/images/demo.png)',
          isDark: false,
        ),
      ),
    ),
  );

  await tester.tap(find.byType(Image).first);
  await tester.pumpAndSettle();

  expect(find.byType(FullscreenImageViewerPage), findsOneWidget);
});
```

- [ ] **Step 2: Run the route/integration tests and verify they fail**

Run: `flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded`

Expected: FAIL because the Markdown renderer still builds plain `Image.network` and `Image.asset` widgets without fullscreen navigation.

- [ ] **Step 3: Wrap network Markdown images with the shared viewer opener**

```dart
return GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () {
    openFullscreenImageViewer(
      context,
      source: FullscreenImageSource.network(
        url: url,
        heroTag: 'markdown-network-$url',
      ),
    );
  },
  child: Hero(
    tag: 'markdown-network-$url',
    child: MarkdownImageFrame(
      isDark: isDark,
      maxHeight: maxImageHeight,
      maxWidth: imgMaxW,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, _, _) => Text(
          '[图片加载失败] $alt',
          style: TextStyle(fontSize: 13, color: imageErrorColor),
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 4: Wrap asset Markdown images the same way**

```dart
return GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () {
    openFullscreenImageViewer(
      context,
      source: FullscreenImageSource.asset(
        assetName: url,
        heroTag: 'markdown-asset-$url',
      ),
    );
  },
  child: Hero(
    tag: 'markdown-asset-$url',
    child: MarkdownImageFrame(
      isDark: isDark,
      maxHeight: maxImageHeight,
      maxWidth: imgMaxW,
      child: Image.asset(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, _, _) => Text(
          '[图片加载失败] $alt',
          style: TextStyle(fontSize: 13, color: imageErrorColor),
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 5: Run the focused test suite**

Run:

```bash
flutter test test/widgets/fullscreen_image_viewer_route_test.dart -r expanded
flutter test test/pages/fullscreen_image_viewer_page_test.dart -r expanded
```

Expected: PASS for shared route integration and viewer page behavior.

- [ ] **Step 6: Run full verification**

Run:

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports no new issues in the touched files, and `flutter test` passes.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/widgets/markdown_renderer.dart \
  test/widgets/fullscreen_image_viewer_route_test.dart \
  test/pages/fullscreen_image_viewer_page_test.dart
git commit -m "feat: reuse fullscreen viewer for markdown images"
```

## Self-Review

### Spec coverage

- Dedicated fullscreen page: covered by Task 2.
- Minimal dark layout and toolbar hiding: covered by Task 2.
- Double-tap zoom, pinch zoom, and pan-above-base-scale behavior: covered by Task 3.
- `fit screen` / `fit width` modes with reset on switch: covered by Tasks 2 and 3.
- Shared viewer path for attachment and Markdown images: covered by Tasks 1, 4, and 5.
- Loading/failure states: covered by Task 2 through `FullscreenImageSurface`.

No uncovered spec requirements remain for v1.

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” steps remain in this plan.
- Each code-changing step includes concrete code to add or adapt.
- Each validation step includes exact commands and expected outcomes.

### Type consistency

- Shared source type stays `FullscreenImageSource` across all tasks.
- Shared page stays `FullscreenImageViewerPage` across all tasks.
- Display mode stays `FullscreenImageDisplayMode` across all tasks.
- Shared opener stays `openFullscreenImageViewer(...)` across all tasks.
