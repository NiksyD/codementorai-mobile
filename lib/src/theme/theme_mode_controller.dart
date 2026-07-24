import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.dark) {
    _loadTheme();
  }

  static const String _key = 'app_theme_mode';

  Future<void> _loadTheme() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedTheme = prefs.getString(_key);
      if (savedTheme == 'light') {
        value = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        value = ThemeMode.dark;
      } else if (savedTheme == 'system') {
        value = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final ThemeMode nextMode = value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(nextMode);
  }
}

final ThemeModeController themeModeController = ThemeModeController();
