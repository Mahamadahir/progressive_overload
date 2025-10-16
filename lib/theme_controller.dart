import 'package:flutter/material.dart';

/// Simple global controller for toggling between light and dark themes.
class ThemeController extends ChangeNotifier {
  bool _useDarkMode = false;

  ThemeMode get mode => _useDarkMode ? ThemeMode.dark : ThemeMode.light;
  bool get isDarkModeEnabled => _useDarkMode;

  void setDarkMode(bool value) {
    if (_useDarkMode == value) return;
    _useDarkMode = value;
    notifyListeners();
  }

  void toggle() => setDarkMode(!_useDarkMode);
}

final ThemeController themeController = ThemeController();
