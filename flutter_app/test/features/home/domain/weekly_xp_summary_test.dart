import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/features/home/domain/weekly_xp_summary.dart';

void main() {
  group('WeeklyXpSummary', () {
    test('uses only Monday through today and leaves future days unplotted', () {
      final summary = WeeklyXpSummary.fromHistory(
        now: DateTime(2026, 7, 14, 18, 30), // Tuesday
        dailyXp: const {
          '2026-07-13': 40,
          '2026-07-14': 25,
          '2026-07-15': 999,
        },
      );

      expect(summary.elapsedDayCount, 2);
      expect(summary.currentTotal, 65);
      expect(summary.currentWeek[0].axisLabel, 'M\n13');
      expect(summary.currentWeek[1].axisLabel, 'T\n14');
      expect(summary.currentWeek[2].xp, 0);
      expect(summary.currentWeek[2].isFuture, isTrue);
    });

    test('compares the same elapsed weekdays with last week', () {
      final summary = WeeklyXpSummary.fromHistory(
        now: DateTime(2026, 7, 14),
        dailyXp: const {
          '2026-07-06': 20,
          '2026-07-07': 30,
          '2026-07-08': 500,
          '2026-07-13': 30,
          '2026-07-14': 45,
        },
      );

      expect(summary.currentTotal, 75);
      expect(summary.previousComparableTotal, 50);
      expect(summary.improvementLabel, '+50%');
      expect(summary.isImproving, isTrue);
    });

    test('formats a decline with a minus and marks it negative', () {
      final summary = WeeklyXpSummary.fromHistory(
        now: DateTime(2026, 7, 14),
        dailyXp: const {
          '2026-07-06': 60,
          '2026-07-07': 40,
          '2026-07-13': 20,
          '2026-07-14': 30,
        },
      );

      expect(summary.improvementLabel, '\u221250%');
      expect(summary.isDeclining, isTrue);
    });

    test('reports zero when neither elapsed period has XP', () {
      final summary = WeeklyXpSummary.fromHistory(
        now: DateTime(2026, 7, 14),
        dailyXp: const {},
      );

      expect(summary.currentTotal, 0);
      expect(summary.previousComparableTotal, 0);
      expect(summary.improvementLabel, '0%');
    });

    test('preserves negative daily XP so the header matches the chart', () {
      final summary = WeeklyXpSummary.fromHistory(
        now: DateTime(2026, 7, 14),
        dailyXp: const {
          '2026-07-13': 0,
          '2026-07-14': -4,
        },
      );

      expect(summary.currentTotal, -4);
      expect(
        summary.currentWeek.map((point) => point.weekdayLabel),
        const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      );
    });
  });
}
