import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../domain/bmi.dart';
import '../../domain/stats.dart';
import '../../providers/providers.dart';
import '../widgets/async_value_view.dart';
import '../widgets/empty_state.dart';
import 'bmi_scale.dart';
import 'height_form.dart';

class BmiPage extends ConsumerStatefulWidget {
  const BmiPage({super.key});

  @override
  ConsumerState<BmiPage> createState() => _BmiPageState();
}

class _BmiPageState extends ConsumerState<BmiPage> {
  bool _editing = false;

  Future<void> _save(int totalInches) async {
    await ref.read(heightProvider.notifier).setHeight(totalInches);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final height = ref.watch(heightProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AsyncValueView(
          value: height,
          data: (inches) {
            if (inches == null) {
              return Column(
                children: [
                  const EmptyState(
                    icon: Icons.height,
                    message: 'BMI needs your height. Enter it below.',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: HeightForm(onSave: _save),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeightCard(
                  totalInches: inches,
                  editing: _editing,
                  onEdit: () => setState(() => _editing = true),
                  onCancel: () => setState(() => _editing = false),
                  onSave: _save,
                ),
                const SizedBox(height: 16),
                _BmiSection(totalInches: inches),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeightCard extends StatelessWidget {
  const _HeightCard({
    required this.totalInches,
    required this.editing,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final int totalInches;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function(int) onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = feetAndInches(totalInches);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: editing
            ? HeightForm(
                initialTotalInches: totalInches,
                onSave: onSave,
                onCancel: onCancel,
              )
            : Row(
                children: [
                  Icon(Icons.height, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Height', style: theme.textTheme.labelLarge),
                        Text(
                          formatHeight(h.feet, h.inches),
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit height'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BmiSection extends ConsumerWidget {
  const _BmiSection({required this.totalInches});

  final int totalInches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(bmiWeightProvider),
      data: (weight) => weight == null
          ? const EmptyState(
              icon: Icons.scale_outlined,
              message: 'Log a weight on the Home page to see your BMI.',
            )
          : _BmiCard(weight: weight, totalInches: totalInches),
    );
  }
}

class _BmiCard extends StatelessWidget {
  const _BmiCard({required this.weight, required this.totalInches});

  final DailyAverage weight;
  final int totalInches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bmi = calculateBmi(weight.averageKg, totalInches);
    final category = bmiCategory(bmi);
    final isToday = weight.day == startOfDay(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your BMI', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatNumber1(roundTo1(bmi)),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: BmiScale.colorFor(category, scheme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isToday
                  ? "Using today's average of ${formatWeight(weight.averageKg)}"
                  : 'Based on weight from ${formatDate(weight.day)} '
                      '(${formatWeight(weight.averageKg)})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            BmiScale(bmi: bmi),
          ],
        ),
      ),
    );
  }
}
