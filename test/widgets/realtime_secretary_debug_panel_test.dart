import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talk/realtime_secretary/realtime_secretary_debug_panel.dart';
import 'package:talk/realtime_secretary/realtime_secretary_service.dart';

void main() {
  testWidgets('debug panel renders secretary activity transcript', (
    tester,
  ) async {
    const entries = [
      RealtimeSecretaryDebugEntry(
        speaker: RealtimeSecretaryDebugSpeaker.secretary,
        text: '日程todo 来了消息。',
      ),
      RealtimeSecretaryDebugEntry(
        speaker: RealtimeSecretaryDebugSpeaker.user,
        text: '小智，啥事',
      ),
      RealtimeSecretaryDebugEntry(
        speaker: RealtimeSecretaryDebugSpeaker.system,
        text: '暗号通过，已发送最近 3 条上下文。',
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RealtimeSecretaryDebugPanel(
            state: RealtimeSecretarySessionState.activeChat,
            entries: entries,
          ),
        ),
      ),
    );

    expect(find.text('实时语音秘书'), findsOneWidget);
    expect(find.text('对话中'), findsOneWidget);
    expect(find.text('日程todo 来了消息。'), findsOneWidget);
    expect(find.text('小智，啥事'), findsOneWidget);
    expect(find.text('暗号通过，已发送最近 3 条上下文。'), findsOneWidget);
  });
}
