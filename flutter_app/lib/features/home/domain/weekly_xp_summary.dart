/// One calendar-day slot in a Monday-to-Sunday XP series.
class DailyXpPoint {
  const DailyXpPoint({
    required this.date,
    required this.xp,
    required this.isFuture,
  });

  final DateTime date;
  final int xp;
  final bool isFuture;

  String get weekdayLabel =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - DateTime.monday];

  String get axisLabel => '$weekdayLabel\n${date.day}';
}

/// Historical XP prepared for the Home weekly-progress card.
///
/// Supports [weekOffset] so the same model can represent the current
/// week (offset 0), last week (offset 1), or two weeks ago (offset 2).
///
/// For the current week the comparison is deliberately elapsed-week to
/// elapsed-week (on a Tuesday, only Mon-Tue are plotted and compared).
/// For past weeks every day is elapsed.
class WeeklyXpSummary {
  const WeeklyXpSummary._({
    required this.currentWeek,
    required this.elapsedDayCount,
    required this.currentTotal,
    required this.previousComparableTotal,
    required this.improvementPercent,
    required this.weekOffset,
    required this.weekStartDate,
  });

  factory WeeklyXpSummary.fromHistory({
    required Map<String, int> dailyXp,
    required DateTime now,
    int weekOffset = 0, // 0 = this week, 1 = last week, 2 = two weeks ago
  }) {
    final today = DateTime(now.year, now.month, now.day);
    // Monday of the target week
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final monday = thisMonday.subtract(Duration(days: weekOffset * 7));

    // For past weeks all 7 days are elapsed; for current week use weekday
    final elapsedDayCount = weekOffset == 0 ? today.weekday : 7;

    final currentWeek = List<DailyXpPoint>.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      final isFuture = weekOffset == 0 && date.isAfter(today);
      return DailyXpPoint(
        date: date,
        xp: isFuture ? 0 : (dailyXp[_dateKey(date)] ?? 0),
        isFuture: isFuture,
      );
    }, growable: false);

    final currentTotal = currentWeek
        .take(elapsedDayCount)
        .fold<int>(0, (total, point) => total + point.xp);

    // Compare against the same elapsed days of the *previous* week
    final previousMonday = monday.subtract(const Duration(days: 7));
    var previousComparableTotal = 0;
    for (var index = 0; index < elapsedDayCount; index++) {
      final date = previousMonday.add(Duration(days: index));
      previousComparableTotal += dailyXp[_dateKey(date)] ?? 0;
    }

    final improvementPercent = previousComparableTotal <= 0
        ? (currentTotal > 0 ? 100.0 : 0.0)
        : ((currentTotal - previousComparableTotal) / previousComparableTotal) *
            100;

    return WeeklyXpSummary._(
      currentWeek: List.unmodifiable(currentWeek),
      elapsedDayCount: elapsedDayCount,
      currentTotal: currentTotal,
      previousComparableTotal: previousComparableTotal,
      improvementPercent: improvementPercent,
      weekOffset: weekOffset,
      weekStartDate: monday,
    );
  }

  final List<DailyXpPoint> currentWeek;
  final int elapsedDayCount;
  final int currentTotal;
  final int previousComparableTotal;
  final double improvementPercent;

  /// 0 = this week, 1 = last week, 2 = two weeks ago
  final int weekOffset;

  /// The Monday that opens this week's window (for display purposes).
  final DateTime weekStartDate;

  bool get isImproving => improvementPercent > 0.05;
  bool get isDeclining => improvementPercent < -0.05;

  String get improvementLabel {
    final rounded = improvementPercent.abs().round();
    if (isImproving) return '+$rounded%';
    if (isDeclining) return '\u2212$rounded%';
    return '0%';
  }

  /// Human-readable label for the week represented by this summary.
  String get weekLabel {
    switch (weekOffset) {
      case 0:
        return 'This Week';
      case 1:
        return 'Last Week';
      default:
        return '${weekOffset} Weeks Ago';
    }
  }

  String get dataSignature => currentWeek
      .map((point) => '${_dateKey(point.date)}:${point.xp}:${point.isFuture}')
      .join('|');
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
