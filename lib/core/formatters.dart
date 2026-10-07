import 'package:intl/intl.dart';

final NumberFormat _oneDecimal = NumberFormat('0.0', 'en_US');

/// `72.4` (one decimal, `.` separator).
String formatNumber1(double value) => _oneDecimal.format(value);

/// `72.4 kg`
String formatWeight(double kg) => '${formatNumber1(kg)} kg';

/// `08:15`
String formatTime(DateTime t) => DateFormat('HH:mm').format(t.toLocal());

/// `Sat, 3 Oct`
String formatDay(DateTime t) => DateFormat('EEE, d MMM').format(t.toLocal());

/// `October 2026`
String formatMonth(DateTime t) => DateFormat('MMMM yyyy').format(t.toLocal());

/// `3 Oct 2026`
String formatDate(DateTime t) => DateFormat('d MMM yyyy').format(t.toLocal());

/// `5 ft 6 in`
String formatHeight(int feet, int inches) => '$feet ft $inches in';

/// `5 entries` / `1 entry`
String pluralEntries(int n) => '$n ${n == 1 ? 'entry' : 'entries'}';
