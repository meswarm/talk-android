import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/local_storage.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemeMode initialThemeMode = ThemeMode.system})
      : _themeMode = initialThemeMode;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark {
    if (_themeMode == ThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
    LocalStorage().saveThemeMode(_themeMode);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    LocalStorage().saveThemeMode(_themeMode);
  }
}
