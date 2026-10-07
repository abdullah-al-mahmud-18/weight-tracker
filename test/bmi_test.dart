import 'package:flutter_test/flutter_test.dart';
import 'package:weight_tracker/domain/bmi.dart';

void main() {
  test('5 ft 6 in is 66 in and 1.6764 m', () {
    final inches = totalInchesFrom(5, 6);
    expect(inches, 66);
    expect(inchesToMeters(inches), closeTo(1.6764, 1e-9));
    expect(feetAndInches(66), (feet: 5, inches: 6));
  });

  test('70 kg at 5 ft 6 in is BMI 24.9, Normal', () {
    final bmi = calculateBmi(70, 66);
    expect(roundTo1(bmi), 24.9);
    expect(bmiCategory(bmi), BmiCategory.normal);
  });

  group('category boundaries use the rounded value', () {
    test('18.5', () {
      expect(bmiCategory(18.44), BmiCategory.underweight);
      expect(bmiCategory(18.45), BmiCategory.normal); // rounds to 18.5
      expect(bmiCategory(18.5), BmiCategory.normal);
    });

    test('25.0', () {
      expect(bmiCategory(24.9), BmiCategory.normal);
      expect(bmiCategory(24.94), BmiCategory.normal);
      expect(bmiCategory(24.96), BmiCategory.overweight); // rounds to 25.0
      expect(bmiCategory(25.0), BmiCategory.overweight);
    });

    test('30.0', () {
      expect(bmiCategory(29.9), BmiCategory.overweight);
      expect(bmiCategory(29.94), BmiCategory.overweight);
      expect(bmiCategory(29.96), BmiCategory.obese); // rounds to 30.0
      expect(bmiCategory(30.0), BmiCategory.obese);
    });
  });
}
