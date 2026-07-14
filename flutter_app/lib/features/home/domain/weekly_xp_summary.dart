/// One calendar-day slot in the current Monday-to-Sunday XP series.
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
/// The comparison is deliberately elapsed-week to elapsed-week. On a
/// Tuesday, Monday and Tuesday are compared with the previous Monday and
/// Tuesday; Wednesday through Sunday remain future slots and are never
/// plotted or counted.
class WeeklyXpSummary {
  const WeeklyXpSummary._({
    required this.currentWeek,
    required this.elapsedDayCount,
    required this.currentTotal,
    required this.previousComparableTotal,
    required this.improvementPercent,
  });

  factory WeeklyXpSummary.fromHistory({
    required Map<String, int> dailyXp,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final elapsedDayCount = today.weekday;

    final currentWeek = List<DailyXpPoint>.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      final isFuture = date.isAfter(today);
      return DailyXpPoint(
        date: date,
        xp: isFuture ? 0 : (dailyXp[_dateKey(date)] ?? 0),
        isFuture: isFuture,
      );
    }, growable: false);

    final currentTotal = currentWeek
        .take(elapsedDayCount)
        .fold<int>(0, (total, point) => total + point.xp);

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
    );
  }

  final List<DailyXpPoint> currentWeek;
  final int elapsedDayCount;
  final int currentTotal;
  final int previousComparableTotal;
  final double improvementPercent;

  bool get isImproving => improvementPercent > 0.05;
  bool get isDeclining => improvementPercent < -0.05;

  String get improvementLabel {
    final rounded = improvementPercent.abs().round();
    if (isImproving) return '+$rounded%';
    if (isDeclining) return '\u2212$rounded%';
    return '0%';
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
