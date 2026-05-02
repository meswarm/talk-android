import 'package:flutter/material.dart';

import '../services/local_storage.dart';

/// 全局字体相对缩放：每档约 ±10%，与系统无障碍字体相乘后作用于 [MediaQuery.textScaler]。
class TextScaleProvider extends ChangeNotifier {
  TextScaleProvider({int initialStep = 0})
      : _step = initialStep.clamp(
          LocalStorage.minTextScaleStep,
          LocalStorage.maxTextScaleStep,
        );

  int _step;

  int get step => _step;

  /// 相对「标准」的乘数，例如 0 档为 1.0，+1 档为 1.1。
  double get factor => 1.0 + _step * 0.1;

  /// 展示用：「标准」或「+1」「-2」。
  String get stepLabel {
    if (_step == 0) return '标准';
    return _step > 0 ? '+$_step' : '$_step';
  }

  Future<void> increment() async {
    if (_step >= LocalStorage.maxTextScaleStep) return;
    _step++;
    notifyListeners();
    await LocalStorage().saveTextScaleStep(_step);
  }

  Future<void> decrement() async {
    if (_step <= LocalStorage.minTextScaleStep) return;
    _step--;
    notifyListeners();
    await LocalStorage().saveTextScaleStep(_step);
  }

  Future<void> reset() async {
    _step = 0;
    notifyListeners();
    await LocalStorage().saveTextScaleStep(_step);
  }
}
