import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../domain/stats.dart';
import '../../providers/providers.dart';
import '../widgets/async_value_view.dart';
import '../widgets/empty_state.dart';
import 'history_chart.dart';

enum HistoryRange { daily, monthly }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryRange _range = HistoryRange.daily;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<HistoryRange>(
          segments: const [
            ButtonSegment(
              value: HistoryRange.daily,
              label: Text('Daily (30 days)'),
              icon: Icon(Icons.calendar_view_day),
            ),
            ButtonSegment(
              value: HistoryRange.monthly,
              label: Text('Monthly (12 months)'),
              icon: Icon(Icons.calendar_month),
            ),
          ],
          selected: {_range},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        const SizedBox(height: 16),
        switch (_range) {
          HistoryRange.daily => const _DailyView(),
          HistoryRange.monthly => const _MonthlyView(),
        },
      ],
    );
  }
}

/// Whole calendar days between two local dates (DST-safe).
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

int _monthsBetween(DateTime from, DateTime to) =>
    (to.year * 12 + to.month) - (from.year * 12 + from.month);

class _DailyView extends ConsumerWidget {
  const _DailyView();

  static const int _days = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(last30DaysProvider),
      data: (days) {
        if (days.isEmpty) {
          return const EmptyState(
            icon: Icons.insights_outlined,
            message: 'No entries in the last 30 days.',
          );
        }
        final today = startOfDay(DateTime.now());
        final start = DateTime(today.year, today.month, today.day - (_days - 1));
        final shortDate = DateFormat('d/M');
        return _HistoryBody(
          chart: HistoryChart(
            points: [
              for (final d in days)
                ChartPoint(_daysBetween(start, d.day), d.averageKg),
            ],
            maxX: _days - 1,
            labelInterval: 7,
            labelFor: (x) => shortDate.format(
              DateTime(start.year, start.month, start.day + x),
            ),
          ),
          rows: [
            for (final d in days.reversed)
              _HistoryRow(
                title: formatDay(d.day),
                subtitle: pluralEntries(d.entryCount),
                value: d.averageKg,
              ),
          ],
        );
      },
    );
  }
}

class _MonthlyView extends ConsumerWidget {
  const _MonthlyView();

  static const int _months = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(last12MonthsProvider),
      data: (months) {
        if (months.isEmpty) {
          return const EmptyState(
            icon: Icons.insights_outlined,
            message: 'No entries in the last 12 months.',
          );
        }
        final current = startOfMonth(DateTime.now());
        final start = DateTime(current.year, current.month - (_months - 1));
        final shortMonth = DateFormat('MMM');
        return _HistoryBody(
          chart: HistoryChart(
            points: [
              for (final m in months)
                ChartPoint(_monthsBetween(start, m.month), m.averageKg),
            ],
            maxX: _months - 1,
            labelInterval: 2,
            labelFor: (x) =>
                shortMonth.format(DateTime(start.year, start.month + x)),
          ),
          rows: [
            for (final m in months.reversed)
              _HistoryRow(
                title: formatMonth(m.month),
                subtitle: '${m.dayCount} ${m.dayCount == 1 ? 'day' : 'days'}',
                value: m.averageKg,
              ),
          ],
        );
      },
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.chart, required this.rows});

  final Widget chart;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(child: chart),
        const SizedBox(height: 16),
        Card(child: Column(children: rows)),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        formatWeight(value),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
