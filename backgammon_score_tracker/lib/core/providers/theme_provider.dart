import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _useSystemThemeKey = 'use_system_theme';

  late SharedPreferences _prefs;
  bool _useSystemTheme = true;
  String _themeMode = 'system';

  bool get useSystemTheme => _useSystemTheme;
  String get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    _prefs = await SharedPreferences.getInstance();
    _useSystemTheme = _prefs.getBool(_useSystemThemeKey) ?? true;
    _themeMode = _prefs.getString(_themeModeKey) ?? 'system';
    notifyListeners();
  }

  Future<void> setUseSystemTheme(bool value) async {
    _useSystemTheme = value;
    await _prefs.setBool(_useSystemThemeKey, value);
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs.setString(_themeModeKey, mode);
    notifyListeners();
  }

  ThemeMode getThemeMode() {
    if (_useSystemTheme) {
      return ThemeMode.system;
    }
    switch (_themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
