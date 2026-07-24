import 'package:shared_preferences/shared_preferences.dart';

abstract class PasswordResetStorage {
  static const String _key = 'is_password_reset_pending';

  static Future<void> setResetPending(bool pending) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, pending);
  }

  static Future<bool> isResetPending() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> clearResetPending() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
