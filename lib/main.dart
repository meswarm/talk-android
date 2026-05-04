import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'keep_alive/keep_alive_controller.dart';
import 'media/media_preview_sizes.dart';
import 'services/local_storage.dart';
import 'services/matrix_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/bubble_max_height_provider.dart';
import 'providers/media_preview_size_provider.dart';
import 'providers/text_scale_provider.dart';
import 'providers/theme_provider.dart';
import 'quick_extract/deepseek_quick_extract_service.dart';
import 'r2/r2_service.dart';
import 'tts/doubao_tts_service.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/conversation_list_page.dart';
import 'pages/chat_page.dart';
import 'route_observer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  final initialThemeMode = await LocalStorage().loadThemeMode();
  final initialTextScaleStep = await LocalStorage().loadTextScaleStep();
  final initialBubbleMaxHeightPct = await LocalStorage()
      .loadBubbleMaxHeightPct();
  final initialBubbleMediaSizes = await LocalStorage()
      .loadBubbleMediaPreviewSizes();
  final initialTableMediaSizes = await LocalStorage()
      .loadTableMediaPreviewSizes();
  runApp(
    TalkApp(
      initialThemeMode: initialThemeMode,
      initialTextScaleStep: initialTextScaleStep,
      initialBubbleMaxHeightPct: initialBubbleMaxHeightPct,
      initialBubbleMediaSizes: initialBubbleMediaSizes,
      initialTableMediaSizes: initialTableMediaSizes,
    ),
  );
}

class TalkApp extends StatefulWidget {
  const TalkApp({
    super.key,
    required this.initialThemeMode,
    required this.initialTextScaleStep,
    required this.initialBubbleMaxHeightPct,
    required this.initialBubbleMediaSizes,
    required this.initialTableMediaSizes,
  });

  final ThemeMode initialThemeMode;
  final int initialTextScaleStep;
  final int initialBubbleMaxHeightPct;
  final MediaPreviewSizes initialBubbleMediaSizes;
  final MediaPreviewSizes initialTableMediaSizes;

  @override
  State<TalkApp> createState() => _TalkAppState();
}

class _TalkAppState extends State<TalkApp> with WidgetsBindingObserver {
  final _matrixService = MatrixService();
  final _notificationService = NotificationService();
  final _r2Service = R2Service();
  final _doubaoTtsService = DoubaoTtsService();
  final _deepSeekQuickExtractService = DeepSeekQuickExtractService();
  final _keepAliveController = KeepAliveController();
  late final AuthProvider _authProvider;
  late final ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_r2Service.bootstrap());
    unawaited(_doubaoTtsService.bootstrap());
    unawaited(_deepSeekQuickExtractService.bootstrap());
    unawaited(_keepAliveController.bootstrap());
    _authProvider = AuthProvider(matrixService: _matrixService);
    _chatProvider = ChatProvider(matrixService: _matrixService);
    _authProvider.addListener(_onAuthChanged);
    _authProvider.init();

    // 注册通知点击回调
    _notificationService.onNotificationTap = _onNotificationTap;
    _notificationService.voiceAnnouncementService = _doubaoTtsService;
  }

  void _onAuthChanged() {
    if (_authProvider.state == AuthState.authenticated) {
      _chatProvider.startListening();
      _notificationService.startListening(_matrixService.client);
    }
  }

  void _onNotificationTap(String roomId) {
    final room = _matrixService.client.getRoomById(roomId);
    if (room == null) return;

    // 使用全局 navigatorKey 导航到聊天页
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ChatPage(room: room)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_onAuthChanged);
    _notificationService.dispose();
    _doubaoTtsService.dispose();
    _deepSeekQuickExtractService.dispose();
    _keepAliveController.dispose();
    _matrixService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ThemeProvider(initialThemeMode: widget.initialThemeMode),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TextScaleProvider(initialStep: widget.initialTextScaleStep),
        ),
        ChangeNotifierProvider(
          create: (_) => BubbleMaxHeightProvider(
            initialPct: widget.initialBubbleMaxHeightPct,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => MediaPreviewSizeProvider(
            bubbleSizes: widget.initialBubbleMediaSizes,
            tableSizes: widget.initialTableMediaSizes,
          ),
        ),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _chatProvider),
        ChangeNotifierProvider.value(value: _r2Service),
        ChangeNotifierProvider.value(value: _doubaoTtsService),
        ChangeNotifierProvider.value(value: _deepSeekQuickExtractService),
        ChangeNotifierProvider.value(value: _keepAliveController),
      ],
      child: Consumer2<ThemeProvider, TextScaleProvider>(
        builder: (context, themeProvider, textScale, _) {
          return MaterialApp(
            title: 'Talk',
            navigatorKey: navigatorKey,
            navigatorObservers: [talkRouteObserver],
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final user = textScale.factor;
              final system = mq.textScaler.scale(1.0);
              final combined = (system * user).clamp(0.72, 1.55);
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(combined)),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.state == AuthState.initial &&
                    !_matrixService.isInitialized) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (auth.state == AuthState.authenticated) {
                  return const ConversationListPage();
                }
                return const LoginPage();
              },
            ),
          );
        },
      ),
    );
  }
}
