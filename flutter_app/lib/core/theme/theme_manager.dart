import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { kids, mature }

final appThemeModeProvider =
    StateNotifierProvider<AppThemeModeNotifier, AppThemeMode>((ref) {
  return AppThemeModeNotifier();
});

class AppThemeModeNotifier extends StateNotifier<AppThemeMode> {
  AppThemeModeNotifier() : super(AppThemeMode.mature) {
    _loadPreference();
  }

  static const _prefKey = 'app_theme_mode';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'kids') {
        state = AppThemeMode.kids;
      } else {
        state = AppThemeMode.mature;
      }
    } catch (_) {
      // Fresh installs and preference failures use Teen & College mode.
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (_) {}
  }

  /// Automatically updates the theme mode based on student grade level:
  /// - Grade 5 to Grade 9 -> AppThemeMode.kids (playful mascot mode)
  /// - Grade 10+ (and College/Adult) -> AppThemeMode.mature (normal mature mode)
  Future<void> setThemeModeFromGradeLevel(int? gradeLevel) async {
    if (gradeLevel == null) return;
    final mode = gradeLevel <= 9 ? AppThemeMode.kids : AppThemeMode.mature;
    await setThemeMode(mode);
  }
}
