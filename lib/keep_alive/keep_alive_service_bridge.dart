import 'package:flutter/services.dart';

abstract class KeepAliveServiceBridge {
  Future<void> start();
  Future<void> stop();
  Future<bool> isRunning();
  Future<void> openBatteryOptimizationSettings();
}

class MethodChannelKeepAliveServiceBridge implements KeepAliveServiceBridge {
  MethodChannelKeepAliveServiceBridge({
    MethodChannel channel = const MethodChannel('talk/keep_alive_service'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> start() async {
    await _invokeVoid('startKeepAliveService');
  }

  @override
  Future<void> stop() async {
    await _invokeVoid('stopKeepAliveService');
  }

  @override
  Future<bool> isRunning() async {
    try {
      return await _channel.invokeMethod<bool>('isKeepAliveServiceRunning') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openBatteryOptimizationSettings() async {
    await _invokeVoid('openBatteryOptimizationSettings');
  }

  Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      return;
    }
  }
}
