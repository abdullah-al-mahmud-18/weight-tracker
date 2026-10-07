/// Meters per inch.
const double metersPerInch = 0.0254;

/// Allowed feet range for height input.
const int minHeightFeet = 3;
const int maxHeightFeet = 8;

/// Total inches from [feet] and [inches].
int totalInchesFrom(int feet, int inches) => feet * 12 + inches;

/// Splits [totalInches] into whole feet and remaining inches.
({int feet, int inches}) feetAndInches(int totalInches) =>
    (feet: totalInches ~/ 12, inches: totalInches % 12);

/// Converts [totalInches] to meters.
double inchesToMeters(int totalInches) => totalInches * metersPerInch;

/// BMI = weight (kg) / height (m)², unrounded.
double calculateBmi(double weightKg, int totalInches) {
  final meters = inchesToMeters(totalInches);
  return weightKg / (meters * meters);
}

/// Rounds [value] to one decimal place.
double roundTo1(double value) => (value * 10).round() / 10;

/// WHO adult BMI categories.
enum BmiCategory {
  underweight('Underweight'),
  normal('Normal'),
  overweight('Overweight'),
  obese('Obese');

  const BmiCategory(this.label);
  final String label;
}

/// Category for [bmi], evaluated on its value rounded to one decimal so the
/// displayed number and label always agree.
BmiCategory bmiCategory(double bmi) {
  final rounded = roundTo1(bmi);
  if (rounded < 18.5) return BmiCategory.underweight;
  if (rounded < 25.0) return BmiCategory.normal;
  if (rounded < 30.0) return BmiCategory.overweight;
  return BmiCategory.obese;
}
