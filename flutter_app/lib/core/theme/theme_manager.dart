import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { kids, mature }

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, AppThemeMode>((ref) {
  return AppThemeModeNotifier();
});

class AppThemeModeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeModeNotifier() : super(AppThemeMode.kids) {
    _loadPreference();
  }

  static const _prefKey = 'app_theme_mode';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'mature') {
        state = AppThemeMode.mature;
      } else {
        state = AppThemeMode.kids;
      }
    } catch (_) {
      // SharedPreferences error or uninitialized, fallback to default (kids)
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }
}
