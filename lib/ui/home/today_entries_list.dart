import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../domain/weight_entry.dart';
import '../../providers/providers.dart';

/// Today's entries, newest first, with swipe-to-delete and undo.
class TodayEntriesList extends ConsumerStatefulWidget {
  const TodayEntriesList({super.key, required this.entries});

  final List<WeightEntry> entries;

  @override
  ConsumerState<TodayEntriesList> createState() => _TodayEntriesListState();
}

class _TodayEntriesListState extends ConsumerState<TodayEntriesList> {
  /// Ids removed from view immediately on swipe; a dismissed [Dismissible]
  /// must leave the tree before the database delete completes.
  final Set<int> _dismissed = {};

  Future<void> _delete(WeightEntry entry) async {
    setState(() => _dismissed.add(entry.id!));
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(entryActionsProvider);
    try {
      await actions.delete(entry);
    } catch (_) {
      if (mounted) setState(() => _dismissed.remove(entry.id));
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the entry.')),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${formatWeight(entry.weightKg)}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await actions.restore(entry);
              if (mounted) setState(() => _dismissed.remove(entry.id));
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.entries.where((e) => !_dismissed.contains(e.id)).toList();
    return Column(
      children: [
        for (final e in visible)
          _EntryTile(
            key: ValueKey(e.id),
            entry: e,
            onDismissed: () => _delete(e),
          ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.entry,
    required this.onDismissed,
  });

  final WeightEntry entry;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss-${entry.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismissed(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: radius,
          ),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: radius),
          child: ListTile(
            leading: Icon(Icons.schedule, color: scheme.primary),
            title: Text(formatTime(entry.localTime)),
            trailing: Text(
              formatWeight(entry.weightKg),
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}
