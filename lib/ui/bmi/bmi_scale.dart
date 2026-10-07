import 'package:flutter/material.dart';

import '../../domain/bmi.dart';

/// Horizontal colour scale of BMI categories with a marker at [bmi].
class BmiScale extends StatelessWidget {
  const BmiScale({super.key, required this.bmi});

  final double bmi;

  static const double _min = 15;
  static const double _max = 40;
  static const List<double> _bounds = [_min, 18.5, 25, 30, _max];

  /// Colour per category, derived from the theme.
  static Color colorFor(BmiCategory c, ColorScheme scheme) => switch (c) {
        BmiCategory.underweight => scheme.tertiary,
        BmiCategory.normal => scheme.primary,
        BmiCategory.overweight => Color.lerp(scheme.primary, scheme.error, 0.6)!,
        BmiCategory.obese => scheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final position = ((roundTo1(bmi) - _min) / (_max - _min)).clamp(0.0, 1.0);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const markerSize = 16.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 18,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          for (var i = 0; i < BmiCategory.values.length; i++)
                            Expanded(
                              flex: ((_bounds[i + 1] - _bounds[i]) * 10).round(),
                              child: Container(
                                height: 12,
                                color: colorFor(BmiCategory.values[i], scheme),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * position - markerSize / 2)
                        .clamp(0.0, width - markerSize),
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: markerSize + 8,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < BmiCategory.values.length; i++)
                  Expanded(
                    flex: ((_bounds[i + 1] - _bounds[i]) * 10).round(),
                    child: Text(
                      BmiCategory.values[i].label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
