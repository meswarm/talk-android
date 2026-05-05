import 'package:flutter_test/flutter_test.dart';
import 'package:talk/realtime_secretary/realtime_secretary_config_store.dart';
import 'package:talk/realtime_secretary/realtime_secretary_models.dart';
import 'package:talk/realtime_secretary/realtime_secretary_service.dart';

void main() {
  test('save enabled config disables voice announcement first', () async {
    var disableVoiceCalls = 0;
    final store = _MemorySecretaryStore();
    final svc = RealtimeSecretaryService(
      store: store,
      bridge: _FakeSecretaryBridge(),
      disableVoiceAnnouncement: () async => disableVoiceCalls += 1,
    );

    await svc.saveConfig(_configured(enabled: true));

    expect(disableVoiceCalls, 1);
    expect(store.config!.enabled, isTrue);
  });

  test('opening announcement only contains room name', () {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );

    expect(svc.buildOpeningAnnouncement('日程todo'), '日程todo 来了消息。');
    expect(svc.buildOpeningAnnouncement('  '), '某个房间 来了消息。');
  });

  test('wake phrase matches when text contains secretary name', () {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );

    expect(svc.matchesWakePhrase('小智，是个啥事', secretaryName: '小智'), isTrue);
    expect(svc.matchesWakePhrase('知道了', secretaryName: '小智'), isFalse);
  });

  test('closing phrase matches common natural stop expressions', () {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );

    expect(svc.isClosingPhrase('好的，我知道了'), isTrue);
    expect(svc.isClosingPhrase('ok 不用管这个了'), isTrue);
    expect(svc.isClosingPhrase('OK，那先结束吧'), isTrue);
    expect(svc.isClosingPhrase('没事了不用处理'), isTrue);
    expect(svc.isClosingPhrase('继续看看是什么消息'), isFalse);
  });

  test('busy session does not trigger another session', () async {
    final bridge = _FakeSecretaryBridge();
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: bridge,
    );
    await svc.saveConfig(_configured(enabled: true));

    final first = await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );
    final second = await svc.tryStartForNewTextMessage(
      roomId: '!b:hs',
      roomName: '别的房间',
      contextLoader: () async => const [],
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(bridge.openings, ['日程todo 来了消息。']);
  });

  test('does not send message context before wake phrase passes', () async {
    final bridge = _FakeSecretaryBridge();
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: bridge,
    );
    await svc.saveConfig(_configured(enabled: true));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [
        SecretaryTextBubble(senderName: 'Alice', body: '明天十点开会'),
        SecretaryTextBubble(senderName: 'Bob', body: '收到'),
      ],
    );

    expect(bridge.contextQueries, isEmpty);
    await svc.handleRecognizedText('不是暗号');
    expect(bridge.contextQueries, isEmpty);
  });

  test(
    'when wake phrase is disabled sends context immediately and starts chat',
    () async {
      final bridge = _FakeSecretaryBridge();
      final svc = RealtimeSecretaryService(
        store: _MemorySecretaryStore(),
        bridge: bridge,
      );
      await svc.saveConfig(
        _configured(
          enabled: true,
          requireWakePhrase: false,
          contextMessageCount: 3,
        ),
      );

      await svc.tryStartForNewTextMessage(
        roomId: '!a:hs',
        roomName: '日程todo',
        triggerMessage: const SecretaryTextBubble(
          senderName: 'todo',
          body: '今晚需要给猫咪洗澡',
        ),
        contextLoader: () async => const [
          SecretaryTextBubble(senderName: 'Alice', body: '旧消息'),
        ],
      );

      expect(svc.state, RealtimeSecretarySessionState.activeChat);
      expect(bridge.contextQueries, isEmpty);
      expect(bridge.initialContexts.single, contains('Alice: 旧消息'));
      expect(bridge.initialContexts.single, contains('todo: 今晚需要给猫咪洗澡'));
      expect(
        svc.debugConversationEntries.map((entry) => entry.text),
        containsAllInOrder([
          '日程todo 来了消息。',
          '已关闭暗号确认，已初始化最近 3 条上下文。',
          contains('todo: 今晚需要给猫咪洗澡'),
        ]),
      );
    },
  );

  test('wake phrase is skipped when disabled', () async {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );
    await svc.saveConfig(_configured(enabled: true, requireWakePhrase: false));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );

    expect(svc.state, RealtimeSecretarySessionState.activeChat);
  });

  test(
    'after wake phrase sends recent text context and enters active chat',
    () async {
      final bridge = _FakeSecretaryBridge();
      final svc = RealtimeSecretaryService(
        store: _MemorySecretaryStore(),
        bridge: bridge,
      );
      await svc.saveConfig(_configured(enabled: true, contextMessageCount: 2));

      await svc.tryStartForNewTextMessage(
        roomId: '!a:hs',
        roomName: '日程todo',
        contextLoader: () async => const [
          SecretaryTextBubble(senderName: 'Old', body: '更早的一条'),
          SecretaryTextBubble(senderName: 'Alice', body: '明天十点开会'),
          SecretaryTextBubble(senderName: 'Bob', body: '收到'),
        ],
      );
      await svc.handleRecognizedText('小智，啥事');

      expect(svc.state, RealtimeSecretarySessionState.activeChat);
      expect(bridge.contextQueries.single, contains('Alice: 明天十点开会'));
      expect(bridge.contextQueries.single, contains('Bob: 收到'));
      expect(bridge.contextQueries.single, isNot(contains('更早的一条')));
    },
  );

  test(
    'triggering message is included when timeline has not caught up',
    () async {
      final bridge = _FakeSecretaryBridge();
      final svc = RealtimeSecretaryService(
        store: _MemorySecretaryStore(),
        bridge: bridge,
      );
      await svc.saveConfig(_configured(enabled: true, contextMessageCount: 3));

      await svc.tryStartForNewTextMessage(
        roomId: '!a:hs',
        roomName: '日程todo',
        triggerMessage: const SecretaryTextBubble(
          senderName: 'todo 🌊',
          body: '你好',
        ),
        contextLoader: () async => const [
          SecretaryTextBubble(senderName: 'Alice', body: '旧消息'),
        ],
      );
      await svc.handleRecognizedText('小智，啥事');

      expect(bridge.contextQueries.single, contains('Alice: 旧消息'));
      expect(bridge.contextQueries.single, contains('todo 🌊: 你好'));
      expect(
        svc.debugConversationEntries.map((entry) => entry.text),
        contains(contains('todo 🌊: 你好')),
      );
    },
  );

  test('closing phrase and wake timeout return to idle', () async {
    final bridge = _FakeSecretaryBridge();
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: bridge,
    );
    await svc.saveConfig(_configured(enabled: true));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );
    svc.debugExpireWakeWait();
    expect(svc.state, RealtimeSecretarySessionState.idle);

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );
    await svc.handleRecognizedText('小智');
    await svc.handleRecognizedText('好的');
    expect(svc.state, RealtimeSecretarySessionState.idle);
    expect(bridge.stopSessionCalls, greaterThanOrEqualTo(2));
  });

  test('native session ended callback hides debug conversation', () async {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );
    await svc.saveConfig(_configured(enabled: true));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );

    expect(svc.shouldShowDebugConversation, isTrue);

    svc.handleNativeSessionEnded(reason: 'engine_stop');

    expect(svc.state, RealtimeSecretarySessionState.idle);
    expect(svc.shouldShowDebugConversation, isFalse);
    expect(svc.debugConversationEntries.last.text, '会话结束。');
  });

  test('active chat idle timeout hides debug conversation', () async {
    final bridge = _FakeSecretaryBridge();
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: bridge,
    );
    await svc.saveConfig(_configured(enabled: true));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );
    await svc.handleRecognizedText('小智，啥事');

    expect(svc.state, RealtimeSecretarySessionState.activeChat);

    await svc.debugExpireActiveChatIdle();

    expect(svc.state, RealtimeSecretarySessionState.idle);
    expect(svc.shouldShowDebugConversation, isFalse);
    expect(bridge.stopSessionCalls, greaterThanOrEqualTo(1));
  });

  test('active chat idle timeout uses saved config value', () async {
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: _FakeSecretaryBridge(),
    );
    await svc.saveConfig(_configured(enabled: true, activeChatIdleSeconds: 10));

    await svc.tryStartForNewTextMessage(
      roomId: '!a:hs',
      roomName: '日程todo',
      contextLoader: () async => const [],
    );
    await svc.handleRecognizedText('小智');

    expect(svc.activeChatIdleSeconds, 10);
  });

  test(
    'native speech activity pauses and resumes active chat idle timeout',
    () async {
      final svc = RealtimeSecretaryService(
        store: _MemorySecretaryStore(),
        bridge: _FakeSecretaryBridge(),
      );
      await svc.saveConfig(_configured(enabled: true));

      await svc.tryStartForNewTextMessage(
        roomId: '!a:hs',
        roomName: '日程todo',
        contextLoader: () async => const [],
      );
      await svc.handleRecognizedText('小智');

      expect(svc.isActiveChatIdleTimerRunning, isTrue);

      svc.handleNativeSpeechStarted();
      expect(svc.isActiveChatIdleTimerRunning, isFalse);

      svc.handleNativeSpeechEnded();
      expect(svc.isActiveChatIdleTimerRunning, isTrue);
    },
  );

  test('test config starts foreground service and calls sdk bridge', () async {
    final bridge = _FakeSecretaryBridge();
    final svc = RealtimeSecretaryService(
      store: _MemorySecretaryStore(),
      bridge: bridge,
    );

    await svc.testConfig(_configured());

    expect(svc.serviceRunning, isTrue);
    expect(bridge.running, isTrue);
    expect(bridge.testConfigs.single.appId, 'app-id');
  });

  test(
    'debug conversation is visible only while secretary is active',
    () async {
      final svc = RealtimeSecretaryService(
        store: _MemorySecretaryStore(),
        bridge: _FakeSecretaryBridge(),
      );
      await svc.saveConfig(_configured(enabled: true));

      expect(svc.shouldShowDebugConversation, isFalse);

      await svc.tryStartForNewTextMessage(
        roomId: '!a:hs',
        roomName: '日程todo',
        contextLoader: () async => const [
          SecretaryTextBubble(senderName: 'Alice', body: '明天十点开会'),
        ],
      );

      expect(svc.shouldShowDebugConversation, isTrue);
      expect(
        svc.debugConversationEntries.single.speaker,
        RealtimeSecretaryDebugSpeaker.secretary,
      );
      expect(svc.debugConversationEntries.single.text, '日程todo 来了消息。');

      await svc.handleRecognizedText('小智，啥事');

      expect(
        svc.debugConversationEntries.map((entry) => entry.text),
        containsAllInOrder([
          '日程todo 来了消息。',
          '小智，啥事',
          '暗号通过，已发送最近 3 条上下文。',
          contains('Alice: 明天十点开会'),
        ]),
      );

      await svc.handleRecognizedText('好的');

      expect(svc.shouldShowDebugConversation, isFalse);
      expect(svc.debugConversationEntries.last.text, '会话结束。');
    },
  );
}

RealtimeSecretaryConfig _configured({
  bool enabled = false,
  bool requireWakePhrase = true,
  int contextMessageCount = 3,
  int activeChatIdleSeconds = 10,
}) {
  return RealtimeSecretaryConfig(
    enabled: enabled,
    appId: 'app-id',
    appKey: 'app-key',
    accessToken: 'token',
    resourceId: 'volc.speech.dialog',
    secretaryName: '小智',
    requireWakePhrase: requireWakePhrase,
    wakeWaitSeconds: 15,
    activeChatIdleSeconds: activeChatIdleSeconds,
    contextMessageCount: contextMessageCount,
  );
}

class _MemorySecretaryStore implements RealtimeSecretaryConfigStore {
  RealtimeSecretaryConfig? config;

  @override
  Future<void> clear() async {
    config = null;
  }

  @override
  Future<RealtimeSecretaryConfig?> load() async => config;

  @override
  Future<void> save(RealtimeSecretaryConfig config) async {
    this.config = config;
  }
}

class _FakeSecretaryBridge implements RealtimeSecretaryBridge {
  final openings = <String>[];
  final initialContexts = <String>[];
  final contextQueries = <String>[];
  final testConfigs = <RealtimeSecretaryConfig>[];
  var stopSessionCalls = 0;
  var running = false;

  @override
  Future<bool> isServiceRunning() async => running;

  @override
  Future<void> sendContextTextQuery(String text) async {
    contextQueries.add(text);
  }

  @override
  Future<void> startForegroundService(RealtimeSecretaryConfig config) async {
    running = true;
  }

  @override
  Future<void> testConfig(RealtimeSecretaryConfig config) async {
    testConfigs.add(config);
  }

  @override
  Future<void> startWakeSession({
    required RealtimeSecretaryConfig config,
    required String roomId,
    required String openingAnnouncement,
    String? initialContextText,
  }) async {
    openings.add(openingAnnouncement);
    if (initialContextText != null) {
      initialContexts.add(initialContextText);
    }
  }

  @override
  Future<void> stopForegroundService() async {
    running = false;
  }

  @override
  Future<void> stopSession() async {
    stopSessionCalls += 1;
  }
}
