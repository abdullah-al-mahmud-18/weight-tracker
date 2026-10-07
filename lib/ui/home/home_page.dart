import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../providers/providers.dart';
import '../widgets/async_value_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/stat_card.dart';
import 'today_entries_list.dart';
import 'weight_input.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final average = ref.watch(todayAverageProvider);
    final todayEntries = ref.watch(todayEntriesProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        AsyncValueView(
          value: average,
          data: (avg) => StatCard(
            icon: Icons.today,
            label: "Today's average",
            value: avg == null
                ? 'No entries today'
                : formatWeight(avg.averageKg),
            subtitle: avg == null
                ? 'Log your first weight below'
                : 'from ${pluralEntries(avg.entryCount)}',
          ),
        ),
        const SizedBox(height: 24),
        const WeightInput(),
        const SizedBox(height: 24),
        Text("Today's entries", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        AsyncValueView(
          value: todayEntries,
          data: (entries) => entries.isEmpty
              ? const EmptyState(
                  icon: Icons.scale_outlined,
                  message: 'Nothing logged yet today.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TodayEntriesList(entries: entries),
                    Text(
                      'Swipe left on an entry to delete it',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
