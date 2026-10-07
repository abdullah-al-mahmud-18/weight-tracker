import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';

/// One point on the history chart.
class ChartPoint {
  const ChartPoint(this.x, this.y);

  /// Position on the x axis (days or months since the start of the window).
  final int x;
  final double y;
}

/// Line chart of averages over a fixed window, oldest → newest.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.points,
    required this.maxX,
    required this.labelFor,
    required this.labelInterval,
  });

  final List<ChartPoint> points;

  /// Last x position of the window (the first is 0).
  final int maxX;

  /// Bottom-axis label for an x position.
  final String Function(int x) labelFor;

  final int labelInterval;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ys = points.map((p) => p.y);
    final minY = (ys.reduce(math.min) - 1).floorToDouble();
    final maxY = (ys.reduce(math.max) + 1).ceilToDouble();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AspectRatio(
      aspectRatio: 1.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 4),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX.toDouble(),
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: scheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(value.toStringAsFixed(0), style: labelStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: labelInterval.toDouble(),
                  getTitlesWidget: (value, meta) {
                    if (value != value.roundToDouble()) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(labelFor(value.toInt()), style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${labelFor(s.x.toInt())}\n${formatWeight(s.y)}',
                      TextStyle(color: scheme.onInverseSurface),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final p in points) FlSpot(p.x.toDouble(), p.y),
                ],
                isCurved: points.length > 2,
                preventCurveOverShooting: true,
                color: scheme.primary,
                barWidth: 3,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 3.5,
                    color: scheme.primary,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
