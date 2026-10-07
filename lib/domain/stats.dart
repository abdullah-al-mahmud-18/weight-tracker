import 'weight_entry.dart';

/// Average of all entries on one local calendar day.
class DailyAverage {
  const DailyAverage({
    required this.day,
    required this.averageKg,
    required this.entryCount,
  });

  /// Local midnight at the start of the day.
  final DateTime day;
  final double averageKg;
  final int entryCount;
}

/// Average of the daily averages within one local calendar month.
class MonthlyAverage {
  const MonthlyAverage({
    required this.month,
    required this.averageKg,
    required this.dayCount,
  });

  /// Local midnight on the first day of the month.
  final DateTime month;
  final double averageKg;

  /// Number of days in the month that have entries.
  final int dayCount;
}

/// Local midnight at the start of the day containing [time].
DateTime startOfDay(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Local midnight on the first day of the month containing [time].
DateTime startOfMonth(DateTime time) {
  final local = time.toLocal();
  return DateTime(local.year, local.month);
}

double _mean(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return sum / count;
}

/// Groups [entries] by local calendar day and averages each day.
///
/// Returns one [DailyAverage] per day that has entries, oldest first.
List<DailyAverage> dailyAverages(Iterable<WeightEntry> entries) {
  final byDay = <DateTime, List<double>>{};
  for (final e in entries) {
    byDay.putIfAbsent(startOfDay(e.localTime), () => []).add(e.weightKg);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      DailyAverage(
        day: day,
        averageKg: _mean(byDay[day]!),
        entryCount: byDay[day]!.length,
      ),
  ];
}

/// Averages entries whose local date matches the date of [day].
///
/// Returns `null` when there are no entries that day.
DailyAverage? dailyAverageFor(Iterable<WeightEntry> entries, DateTime day) {
  final target = startOfDay(day);
  final weights = [
    for (final e in entries)
      if (startOfDay(e.localTime) == target) e.weightKg,
  ];
  if (weights.isEmpty) return null;
  return DailyAverage(
    day: target,
    averageKg: _mean(weights),
    entryCount: weights.length,
  );
}

/// The daily average of the most recent day that has entries, or `null`.
DailyAverage? latestDailyAverage(Iterable<WeightEntry> entries) {
  final days = dailyAverages(entries);
  return days.isEmpty ? null : days.last;
}

/// Daily averages for the last [days] local calendar days (today included).
///
/// Only days with entries are returned, oldest first.
List<DailyAverage> dailyAveragesForLastDays(
  Iterable<WeightEntry> entries,
  DateTime now, {
  int days = 30,
}) {
  final today = startOfDay(now);
  final start = DateTime(today.year, today.month, today.day - (days - 1));
  final end = DateTime(today.year, today.month, today.day + 1);
  return dailyAverages(_inRange(entries, start, end));
}

/// Monthly averages, each the mean of that month's daily averages.
///
/// Returns one [MonthlyAverage] per month that has entries, oldest first.
List<MonthlyAverage> monthlyAverages(Iterable<WeightEntry> entries) {
  final byMonth = <DateTime, List<double>>{};
  for (final d in dailyAverages(entries)) {
    byMonth.putIfAbsent(startOfMonth(d.day), () => []).add(d.averageKg);
  }
  final months = byMonth.keys.toList()..sort();
  return [
    for (final month in months)
      MonthlyAverage(
        month: month,
        averageKg: _mean(byMonth[month]!),
        dayCount: byMonth[month]!.length,
      ),
  ];
}

/// Monthly averages for the last [months] calendar months (current included).
///
/// Only months with entries are returned, oldest first.
List<MonthlyAverage> monthlyAveragesForLastMonths(
  Iterable<WeightEntry> entries,
  DateTime now, {
  int months = 12,
}) {
  final current = startOfMonth(now);
  final start = DateTime(current.year, current.month - (months - 1));
  final end = DateTime(current.year, current.month + 1);
  return monthlyAverages(_inRange(entries, start, end));
}

/// Entries whose local time is in `[start, end)`.
Iterable<WeightEntry> _inRange(
  Iterable<WeightEntry> entries,
  DateTime start,
  DateTime end,
) =>
    entries.where((e) {
      final t = e.localTime;
      return !t.isBefore(start) && t.isBefore(end);
    });
