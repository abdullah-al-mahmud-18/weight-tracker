import 'package:flutter_test/flutter_test.dart';
import 'package:weight_tracker/domain/csv_codec.dart';
import 'package:weight_tracker/domain/weight_entry.dart';

void main() {
  test('export -> import round trip is lossless', () {
    final entries = [
      WeightEntry.at(DateTime(2026, 10, 3, 8, 15), 72.4),
      WeightEntry.at(DateTime(2026, 10, 3, 20, 1, 2, 345), 73.0),
      WeightEntry.at(DateTime.utc(2025, 1, 1, 0, 0, 0, 7), 299.9),
      WeightEntry.at(DateTime(2026, 6, 15, 12), 20.0),
    ];
    final csv = encodeEntries(entries);
    final decoded = decodeEntries(csv);

    expect(decoded.invalidRows, 0);
    final expected = entries.toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    expect(
      decoded.entries.map((e) => (e.timestampMs, e.weightKg)),
      expected.map((e) => (e.timestampMs, e.weightKg)),
    );
  });

  test('export writes header, oldest first, with offset', () {
    final csv = encodeEntries([
      WeightEntry.at(DateTime(2026, 10, 4, 9), 71.0),
      WeightEntry.at(DateTime(2026, 10, 3, 8, 15), 72.4),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'timestamp,weight_kg');
    expect(lines[1], startsWith('2026-10-03T08:15:00'));
    expect(lines[1], matches(RegExp(r'[+-]\d\d:\d\d,72\.4$')));
    expect(lines[2], startsWith('2026-10-04T09:00:00'));
  });

  test('timestamp formatter includes milliseconds only when non-zero', () {
    expect(
      formatTimestampWithOffset(DateTime(2026, 10, 3, 8, 15)),
      matches(RegExp(r'^2026-10-03T08:15:00[+-]\d\d:\d\d$')),
    );
    expect(
      formatTimestampWithOffset(DateTime(2026, 10, 3, 8, 15, 0, 5)),
      matches(RegExp(r'^2026-10-03T08:15:00\.005[+-]\d\d:\d\d$')),
    );
  });

  test('header order independence and case-insensitivity', () {
    final decoded = decodeEntries(
      'Weight_KG,note,TIMESTAMP\n'
      '72.4,hello,2026-10-03T08:15:00+06:00\n',
    );
    expect(decoded.invalidRows, 0);
    expect(decoded.entries.single.weightKg, 72.4);
    expect(
      decoded.entries.single.timestampMs,
      DateTime.utc(2026, 10, 3, 2, 15).millisecondsSinceEpoch,
    );
  });

  test('rows with bad data are counted as invalid', () {
    final decoded = decodeEntries(
      'timestamp,weight_kg\n'
      '2026-10-03T08:15:00+06:00,72.4\n'
      'not-a-date,72.4\n'
      '2026-10-03T09:15:00+06:00,abc\n'
      '2026-10-03T10:15:00+06:00,19.9\n'
      '2026-10-03T11:15:00+06:00,300.1\n'
      '2026-10-03T12:15:00+06:00\n'
      '\n',
    );
    expect(decoded.entries, hasLength(1));
    expect(decoded.invalidRows, 5);
  });

  test('offset and no-offset timestamps both parse', () {
    final decoded = decodeEntries(
      'timestamp,weight_kg\n'
      '2026-10-03T08:15:00+06:00,70\n'
      '2026-10-03T08:15:00-05:30,71\n'
      '2026-10-03T08:15:00Z,72\n'
      '2026-10-03T08:15:00,73\n',
    );
    expect(decoded.invalidRows, 0);
    final ms = decoded.entries.map((e) => e.timestampMs).toList();
    expect(ms[0], DateTime.utc(2026, 10, 3, 2, 15).millisecondsSinceEpoch);
    expect(ms[1], DateTime.utc(2026, 10, 3, 13, 45).millisecondsSinceEpoch);
    expect(ms[2], DateTime.utc(2026, 10, 3, 8, 15).millisecondsSinceEpoch);
    // No offset: local time.
    expect(ms[3], DateTime(2026, 10, 3, 8, 15).millisecondsSinceEpoch);
  });

  test('UTF-8 BOM and CRLF line endings are handled', () {
    final decoded = decodeEntries(
      '\uFEFFtimestamp,weight_kg\r\n2026-10-03T08:15:00+06:00,72.4\r\n',
    );
    expect(decoded.entries, hasLength(1));
    expect(decoded.invalidRows, 0);
  });

  test('missing header throws', () {
    expect(() => decodeEntries('date,weight\n2026-10-03,70\n'),
        throwsA(isA<CsvHeaderException>()));
    expect(() => decodeEntries(''), throwsA(isA<CsvHeaderException>()));
  });
}
