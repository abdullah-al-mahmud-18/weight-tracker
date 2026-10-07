/// Lowest weight (kg) accepted from input or import.
const double minWeightKg = 20.0;

/// Highest weight (kg) accepted from input or import.
const double maxWeightKg = 300.0;

/// A single weigh-in. Immutable.
class WeightEntry {
  const WeightEntry({
    this.id,
    required this.timestampMs,
    required this.weightKg,
  });

  /// Creates an entry from a [DateTime] (any time zone).
  factory WeightEntry.at(DateTime time, double weightKg, {int? id}) =>
      WeightEntry(
        id: id,
        timestampMs: time.millisecondsSinceEpoch,
        weightKg: weightKg,
      );

  /// Database row id; `null` until the entry has been stored.
  final int? id;

  /// Milliseconds since epoch (UTC).
  final int timestampMs;

  /// Weight in kilograms, as entered.
  final double weightKg;

  /// The timestamp in the device's local time zone.
  DateTime get localTime => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  @override
  bool operator ==(Object other) =>
      other is WeightEntry &&
      other.id == id &&
      other.timestampMs == timestampMs &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(id, timestampMs, weightKg);

  @override
  String toString() =>
      'WeightEntry(id: $id, timestampMs: $timestampMs, weightKg: $weightKg)';
}

/// Whether [weightKg] is within the accepted range.
bool isWeightInRange(double weightKg) =>
    weightKg >= minWeightKg && weightKg <= maxWeightKg;

/// Result of validating user-typed weight text.
class WeightInputResult {
  const WeightInputResult.valid(double this.value) : error = null;
  const WeightInputResult.invalid(String this.error) : value = null;

  final double? value;
  final String? error;

  bool get isValid => value != null;
}

final RegExp _weightPattern = RegExp(r'^\d+([.,]\d)?$');

/// Validates weight text typed by the user.
///
/// Accepts `.` or `,` as decimal separator, at most one decimal place, and a
/// value between [minWeightKg] and [maxWeightKg].
WeightInputResult parseWeightInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return const WeightInputResult.invalid('Enter a weight');
  if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(text)) {
    return const WeightInputResult.invalid('Enter a valid number');
  }
  if (!_weightPattern.hasMatch(text)) {
    return const WeightInputResult.invalid('Use at most 1 decimal place');
  }
  final value = double.parse(text.replaceAll(',', '.'));
  if (!isWeightInRange(value)) {
    return const WeightInputResult.invalid('Weight must be 20–300 kg');
  }
  return WeightInputResult.valid(value);
}
