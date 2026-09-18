import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:social_study_app/core/theme/theme_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeModeNotifier grade level switching', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Grades 5 through 9 automatically switch to Kids Mode (with mascot)',
        () async {
      final notifier = AppThemeModeNotifier();

      for (final grade in [5, 6, 7, 8, 9]) {
        await notifier.setThemeModeFromGradeLevel(grade);
        expect(
          notifier.state,
          equals(AppThemeMode.kids),
          reason: 'Grade $grade should switch to Kids Mode',
        );
      }
    });

    test('Grades 10 and above automatically switch to Mature Mode', () async {
      final notifier = AppThemeModeNotifier();

      // Start in kids mode
      await notifier.setThemeMode(AppThemeMode.kids);
      expect(notifier.state, equals(AppThemeMode.kids));

      for (final grade in [10, 11, 12, 13, 14]) {
        await notifier.setThemeModeFromGradeLevel(grade);
        expect(
          notifier.state,
          equals(AppThemeMode.mature),
          reason: 'Grade $grade should switch to Mature Mode',
        );
      }
    });

    test('Changing from Grade 7 (Kids) to Grade 10 (Mature) and back',
        () async {
      final notifier = AppThemeModeNotifier();

      await notifier.setThemeModeFromGradeLevel(7);
      expect(notifier.state, equals(AppThemeMode.kids));

      await notifier.setThemeModeFromGradeLevel(10);
      expect(notifier.state, equals(AppThemeMode.mature));

      await notifier.setThemeModeFromGradeLevel(9);
      expect(notifier.state, equals(AppThemeMode.kids));
    });

    test('Null grade level does not modify current theme mode', () async {
      final notifier = AppThemeModeNotifier();
      await notifier.setThemeMode(AppThemeMode.kids);

      await notifier.setThemeModeFromGradeLevel(null);
      expect(notifier.state, equals(AppThemeMode.kids));
    });
  });
}
