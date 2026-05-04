import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talk/media/media_preview_sizes.dart';
import 'package:talk/pages/settings_page.dart';
import 'package:talk/providers/bubble_max_height_provider.dart';
import 'package:talk/providers/media_preview_size_provider.dart';
import 'package:talk/providers/text_scale_provider.dart';
import 'package:talk/providers/theme_provider.dart';
import 'package:talk/services/local_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage().resetPrefsCacheForTest();
  });

  testWidgets('settings page is a top-level directory of setting groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TextScaleProvider()),
          ChangeNotifierProvider(
            create: (_) => BubbleMaxHeightProvider(
              initialPct: LocalStorage.defaultBubbleMaxHeightPct,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => MediaPreviewSizeProvider(
              bubbleSizes: MediaPreviewSizes.bubbleDefaults,
              tableSizes: MediaPreviewSizes.tableDefaults,
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('R2 存储'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('聊天界面'), findsOneWidget);
    expect(find.text('图片与上传'), findsOneWidget);
    expect(find.text('AI 与快捷操作'), findsOneWidget);
    expect(find.text('语音播报'), findsOneWidget);
    expect(find.text('推送通知'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('appearance settings contains theme and text size controls', (
    tester,
  ) async {
    final theme = ThemeProvider();
    final textScale = TextScaleProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider<TextScaleProvider>.value(value: textScale),
        ],
        child: const MaterialApp(home: AppearanceSettingsPage()),
      ),
    );

    expect(find.text('主题'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('白天'), findsOneWidget);
    expect(find.text('夜间'), findsOneWidget);
    expect(find.text('界面字体'), findsOneWidget);
  });
}
