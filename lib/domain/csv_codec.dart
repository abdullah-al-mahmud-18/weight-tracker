import 'package:csv/csv.dart';

import 'weight_entry.dart';

const String _timestampHeader = 'timestamp';
const String _weightHeader = 'weight_kg';

final Csv _csv = Csv(lineDelimiter: '\n', autoDetect: false);

/// Thrown when a CSV file lacks the required header columns.
class CsvHeaderException implements Exception {
  const CsvHeaderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parsed CSV content.
class CsvDecodeResult {
  const CsvDecodeResult({required this.entries, required this.invalidRows});

  final List<WeightEntry> entries;

  /// Data rows skipped because of a bad timestamp or weight.
  final int invalidRows;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Formats [time] as ISO 8601 local time with an explicit UTC offset,
/// e.g. `2026-10-03T08:15:00+06:00`. Milliseconds are included when non-zero.
String formatTimestampWithOffset(DateTime time) {
  final t = time.toLocal();
  final buf = StringBuffer()
    ..write(t.year.toString().padLeft(4, '0'))
    ..write('-${_two(t.month)}-${_two(t.day)}')
    ..write('T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}');
  if (t.millisecond != 0) {
    buf.write('.${t.millisecond.toString().padLeft(3, '0')}');
  }
  final offset = t.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  buf.write('$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}');
  return buf.toString();
}

/// Parses an ISO 8601 timestamp. With an offset (or `Z`) it is interpreted
/// as that instant; without one it is treated as local time. Returns `null`
/// when unparsable.
DateTime? parseTimestamp(String text) =>
    DateTime.tryParse(text.trim())?.toUtc();

/// Encodes [entries] as CSV (header + rows, oldest first).
String encodeEntries(Iterable<WeightEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
  final rows = <List<String>>[
    [_timestampHeader, _weightHeader],
    for (final e in sorted)
      [
        formatTimestampWithOffset(e.localTime),
        e.weightKg.toString(),
      ],
  ];
  return '${_csv.encode(rows)}\n';
}

/// Decodes CSV [text] into entries.
///
/// The header must contain `timestamp` and `weight_kg` (case-insensitive,
/// any order). Rows with an unparsable timestamp or a weight outside
/// 20–300 kg are counted in [CsvDecodeResult.invalidRows].
///
/// Throws [CsvHeaderException] if the header is missing or incomplete.
CsvDecodeResult decodeEntries(String text) {
  final cleaned = text.startsWith('﻿') ? text.substring(1) : text;
  final rows = _csv
      .decode(cleaned)
      .where((r) => r.any((f) => f.toString().trim().isNotEmpty))
      .toList();
  if (rows.isEmpty) {
    throw const CsvHeaderException('The file is empty.');
  }

  final header = [for (final f in rows.first) f.toString().trim().toLowerCase()];
  final tsIndex = header.indexOf(_timestampHeader);
  final wIndex = header.indexOf(_weightHeader);
  if (tsIndex < 0 || wIndex < 0) {
    throw const CsvHeaderException(
      'The file must have "timestamp" and "weight_kg" columns.',
    );
  }

  final entries = <WeightEntry>[];
  var invalid = 0;
  for (final row in rows.skip(1)) {
    if (row.length <= tsIndex || row.length <= wIndex) {
      invalid++;
      continue;
    }
    final time = parseTimestamp(row[tsIndex].toString());
    final weight = double.tryParse(row[wIndex].toString().trim());
    if (time == null || weight == null || !isWeightInRange(weight)) {
      invalid++;
      continue;
    }
    entries.add(WeightEntry.at(time, weight));
  }
  return CsvDecodeResult(entries: entries, invalidRows: invalid);
}
