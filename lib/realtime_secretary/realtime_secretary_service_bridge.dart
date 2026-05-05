import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'realtime_secretary_models.dart';

abstract class RealtimeSecretaryBridge {
  Future<void> startForegroundService(RealtimeSecretaryConfig config);
  Future<void> stopForegroundService();
  Future<bool> isServiceRunning();
  Future<void> testConfig(RealtimeSecretaryConfig config);
  Future<void> startWakeSession({
    required RealtimeSecretaryConfig config,
    required String roomId,
    required String openingAnnouncement,
    String? initialContextText,
  });
  Future<void> sendContextTextQuery(String text);
  Future<void> stopSession();
}

class MethodChannelRealtimeSecretaryBridge implements RealtimeSecretaryBridge {
  MethodChannelRealtimeSecretaryBridge({
    MethodChannel channel = const MethodChannel('talk/realtime_secretary'),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  Future<void> Function(String text)? onRecognizedText;
  void Function({String? reason})? onSessionEnded;
  void Function()? onSpeechStarted;
  void Function()? onSpeechEnded;

  @override
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isRealtimeSecretaryServiceRunning',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> sendContextTextQuery(String text) {
    return _invokeVoid('sendRealtimeSecretaryContextTextQuery', {'text': text});
  }

  @override
  Future<void> startForegroundService(RealtimeSecretaryConfig config) {
    return _invokeVoid('startRealtimeSecretaryService', config.toJson());
  }

  @override
  Future<void> testConfig(RealtimeSecretaryConfig config) {
    return _invokeVoid('testRealtimeSecretaryConfig', config.toJson());
  }

  @override
  Future<void> startWakeSession({
    required RealtimeSecretaryConfig config,
    required String roomId,
    required String openingAnnouncement,
    String? initialContextText,
  }) {
    return _invokeVoid('startRealtimeSecretaryWakeSession', {
      ...config.toJson(),
      'roomId': roomId,
      'openingAnnouncement': openingAnnouncement,
      'initialContextText': ?initialContextText,
    });
  }

  @override
  Future<void> stopForegroundService() {
    return _invokeVoid('stopRealtimeSecretaryService');
  }

  @override
  Future<void> stopSession() {
    return _invokeVoid('stopRealtimeSecretarySession');
  }

  Future<void> _invokeVoid(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onRealtimeSecretarySessionEnded') {
      final args = call.arguments;
      final reason = args is Map ? args['reason']?.toString() : null;
      onSessionEnded?.call(reason: reason);
      return;
    }
    if (call.method == 'onRealtimeSecretarySpeechStarted') {
      onSpeechStarted?.call();
      return;
    }
    if (call.method == 'onRealtimeSecretarySpeechEnded') {
      onSpeechEnded?.call();
      return;
    }
    if (call.method != 'onRealtimeSecretaryAsrText') return;
    final args = call.arguments;
    final raw = args is Map ? args['text'] : args;
    final text = _extractRecognizedText(raw);
    if (text.trim().isEmpty) return;
    await onRecognizedText?.call(text);
  }

  String _extractRecognizedText(Object? raw) {
    if (raw == null) return '';
    if (raw is String) {
      try {
        return _extractRecognizedText(jsonDecode(raw));
      } catch (_) {
        return raw;
      }
    }
    if (raw is Map) {
      for (final key in const ['text', 'utterance', 'asr_text', 'result']) {
        final value = raw[key];
        final text = _extractRecognizedText(value);
        if (text.trim().isNotEmpty) return text;
      }
      return raw.values.map(_extractRecognizedText).join(' ');
    }
    if (raw is Iterable) {
      return raw.map(_extractRecognizedText).join(' ');
    }
    return raw.toString();
  }
}
