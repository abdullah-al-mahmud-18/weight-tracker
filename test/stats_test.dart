import 'package:flutter_test/flutter_test.dart';
import 'package:weight_tracker/domain/stats.dart';
import 'package:weight_tracker/domain/weight_entry.dart';

WeightEntry e(DateTime local, double kg) => WeightEntry.at(local, kg);

void main() {
  group('dailyAverages', () {
    test('multiple entries in one day average correctly', () {
      final result = dailyAverages([
        e(DateTime(2026, 10, 3, 7), 72.0),
        e(DateTime(2026, 10, 3, 12), 73.0),
        e(DateTime(2026, 10, 3, 21), 74.5),
      ]);
      expect(result, hasLength(1));
      expect(result.single.day, DateTime(2026, 10, 3));
      expect(result.single.averageKg, closeTo(73.1667, 1e-4));
      expect(result.single.entryCount, 3);
    });

    test('entries at 23:59 and 00:01 land in different days', () {
      final result = dailyAverages([
        e(DateTime(2026, 10, 3, 23, 59), 70.0),
        e(DateTime(2026, 10, 4, 0, 1), 80.0),
      ]);
      expect(result.map((d) => d.day), [
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
      ]);
      expect(result.map((d) => d.averageKg), [70.0, 80.0]);
    });

    test('results are sorted oldest first', () {
      final result = dailyAverages([
        e(DateTime(2026, 10, 5, 8), 71.0),
        e(DateTime(2026, 10, 1, 8), 70.0),
      ]);
      expect(result.first.day, DateTime(2026, 10, 1));
      expect(result.last.day, DateTime(2026, 10, 5));
    });

    test('empty input returns empty results', () {
      expect(dailyAverages([]), isEmpty);
      expect(latestDailyAverage([]), isNull);
      expect(dailyAverageFor([], DateTime(2026, 10, 3)), isNull);
    });
  });

  group('dailyAveragesForLastDays', () {
    final now = DateTime(2026, 10, 7, 15, 30);

    test('30-day window includes today and excludes day 31', () {
      final result = dailyAveragesForLastDays([
        e(DateTime(2026, 10, 7, 23, 59), 70.0), // today
        e(DateTime(2026, 9, 8, 0, 0), 71.0), // 29 days ago: day 30
        e(DateTime(2026, 9, 7, 23, 59), 72.0), // 30 days ago: day 31
        e(DateTime(2026, 10, 8, 0, 0), 73.0), // tomorrow
      ], now);
      expect(result.map((d) => d.day), [
        DateTime(2026, 9, 8),
        DateTime(2026, 10, 7),
      ]);
    });

    test('window spanning a DST change still covers 30 calendar days', () {
      // US/EU clocks change in March; run with TZ=America/New_York to
      // exercise the shift.
      final result = dailyAveragesForLastDays([
        e(DateTime(2026, 2, 19, 0, 0), 70.0), // day 30
        e(DateTime(2026, 2, 18, 23, 59), 71.0), // day 31
      ], DateTime(2026, 3, 20, 12));
      expect(result.map((d) => d.day), [DateTime(2026, 2, 19)]);
    });

    test('empty input returns empty results', () {
      expect(dailyAveragesForLastDays([], now), isEmpty);
    });
  });

  group('monthlyAverages', () {
    test('monthly average is the mean of daily averages', () {
      final result = monthlyAverages([
        // Oct 1: four entries, daily average 80.
        e(DateTime(2026, 10, 1, 7), 79.0),
        e(DateTime(2026, 10, 1, 9), 81.0),
        e(DateTime(2026, 10, 1, 12), 79.0),
        e(DateTime(2026, 10, 1, 20), 81.0),
        // Oct 2: one entry, 70.
        e(DateTime(2026, 10, 2, 7), 70.0),
      ]);
      expect(result, hasLength(1));
      expect(result.single.month, DateTime(2026, 10));
      // Mean of daily averages (80 + 70) / 2 = 75, not entry mean 78.
      expect(result.single.averageKg, closeTo(75.0, 1e-9));
      expect(result.single.dayCount, 2);
    });

    test('12-month window includes current month and excludes month 13', () {
      final now = DateTime(2026, 10, 7);
      final result = monthlyAveragesForLastMonths([
        e(DateTime(2026, 10, 31, 23, 59), 70.0),
        e(DateTime(2025, 11, 1, 0, 0), 71.0),
        e(DateTime(2025, 10, 31, 23, 59), 72.0),
        e(DateTime(2026, 11, 1, 0, 0), 73.0),
      ], now);
      expect(result.map((m) => m.month), [
        DateTime(2025, 11),
        DateTime(2026, 10),
      ]);
    });

    test('window crosses year boundary in January', () {
      final now = DateTime(2026, 1, 15);
      final result = monthlyAveragesForLastMonths([
        e(DateTime(2025, 2, 1), 70.0),
        e(DateTime(2025, 1, 31), 71.0),
      ], now);
      expect(result.map((m) => m.month), [DateTime(2025, 2)]);
    });

    test('empty input returns empty results', () {
      expect(monthlyAverages([]), isEmpty);
      expect(monthlyAveragesForLastMonths([], DateTime(2026, 10)), isEmpty);
    });
  });

  group('parseWeightInput', () {
    test('accepts dot and comma', () {
      expect(parseWeightInput('72.4').value, 72.4);
      expect(parseWeightInput('72,4').value, 72.4);
      expect(parseWeightInput(' 72 ').value, 72.0);
    });

    test('accepts up to two decimal places', () {
      expect(parseWeightInput('88.65').value, 88.65);
      expect(parseWeightInput('88,65').value, 88.65);
      expect(parseWeightInput('88.5').value, 88.5);
    });

    test('rejects invalid input', () {
      expect(parseWeightInput('').isValid, isFalse);
      expect(parseWeightInput('abc').isValid, isFalse);
      expect(parseWeightInput('72.456').isValid, isFalse);
      expect(parseWeightInput('72.').isValid, isFalse);
      expect(parseWeightInput('72.4.5').isValid, isFalse);
      expect(parseWeightInput('7e1').isValid, isFalse);
      expect(parseWeightInput('19.9').isValid, isFalse);
      expect(parseWeightInput('300.1').isValid, isFalse);
      expect(parseWeightInput('-70').isValid, isFalse);
    });

    test('accepts range boundaries', () {
      expect(parseWeightInput('20').isValid, isTrue);
      expect(parseWeightInput('300.0').isValid, isTrue);
      expect(parseWeightInput('300.00').isValid, isTrue);
      expect(parseWeightInput('300.01').isValid, isFalse);
    });
  });

  group('isPartialWeightInput', () {
    test('allows digits and one separator with up to two decimals', () {
      for (final t in ['', '8', '88', '88.', '88,', '88.6', '88.65', '.5']) {
        expect(isPartialWeightInput(t), isTrue, reason: t);
      }
    });

    test('blocks letters, symbols and extra decimals', () {
      for (final t in [
        'a', '88a', '-', '-8', '+8', '8 8', '88.6.', '88.,', '88.655', '1000',
        '8e2', '88%',
      ]) {
        expect(isPartialWeightInput(t), isFalse, reason: t);
      }
    });
  });
}
