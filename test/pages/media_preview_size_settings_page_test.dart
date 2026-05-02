import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/media/media_preview_sizes.dart';
import 'package:talk/pages/media_preview_size_settings_page.dart';
import 'package:talk/providers/media_preview_size_provider.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  testWidgets('bubble settings page updates bubble image width only', (
    tester,
  ) async {
    final provider = MediaPreviewSizeProvider(
      bubbleSizes: MediaPreviewSizes.bubbleDefaults,
      tableSizes: MediaPreviewSizes.tableDefaults,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<MediaPreviewSizeProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: MediaPreviewSizeSettingsPage(
            contextType: MediaPreviewContext.bubble,
          ),
        ),
      ),
    );

    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(-220, 0));
    await tester.pumpAndSettle();

    expect(provider.bubbleSizes.imageWidth < 260, isTrue);
    expect(provider.tableSizes, MediaPreviewSizes.tableDefaults);
  });

  testWidgets('table settings page shows table defaults', (tester) async {
    final provider = MediaPreviewSizeProvider(
      bubbleSizes: MediaPreviewSizes.bubbleDefaults,
      tableSizes: MediaPreviewSizes.tableDefaults,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<MediaPreviewSizeProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: MediaPreviewSizeSettingsPage(
            contextType: MediaPreviewContext.table,
          ),
        ),
      ),
    );

    expect(find.text('表格内媒体尺寸'), findsOneWidget);
    expect(find.text('96 px', skipOffstage: false), findsNWidgets(2));
    expect(find.text('72 px', skipOffstage: false), findsNWidgets(2));
    expect(find.text('240 px', skipOffstage: false), findsOneWidget);
    expect(find.text('180 px', skipOffstage: false), findsOneWidget);
    expect(find.text('44 px', skipOffstage: false), findsNWidgets(2));
  });
}
