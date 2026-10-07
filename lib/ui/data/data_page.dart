import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../domain/csv_codec.dart';
import '../../providers/providers.dart';
import '../../services/downloads_service.dart';
import '../../services/import_service.dart';

class DataPage extends ConsumerStatefulWidget {
  const DataPage({super.key});

  @override
  ConsumerState<DataPage> createState() => _DataPageState();
}

class _DataPageState extends ConsumerState<DataPage> {
  bool _busy = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
        try {
          final entries = await ref.read(entriesProvider.future);
          if (entries.isEmpty) {
            _snack('Nothing to export yet.');
            return;
          }
          final name = DownloadsService.exportFileName(DateTime.now());
          final saved = await ref
              .read(downloadsServiceProvider)
              .saveCsv(name, encodeEntries(entries));
          if (mounted) _snack('Saved to Downloads: $saved');
        } on DownloadsException catch (e) {
          if (mounted) _snack(e.message);
        } catch (_) {
          if (mounted) _snack('Export failed. Please try again.');
        }
      });

  Future<void> _import() => _run(() async {
        try {
          final summary = await ref.read(entryActionsProvider).importCsv();
          if (summary != null && mounted) await _showSummary(summary);
        } on ImportException catch (e) {
          if (mounted) _snack(e.message);
        } catch (_) {
          if (mounted) _snack('Import failed. Please try again.');
        }
      });

  Future<void> _showSummary(ImportSummary s) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.task_alt),
          title: const Text('Import complete'),
          content: Text(
            'Imported ${s.imported} · '
            'Skipped ${s.duplicates} duplicates · '
            '${s.invalid} invalid rows',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(entriesProvider).value?.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        _ActionCard(
          icon: Icons.file_download_outlined,
          title: 'Export',
          description: count == null
              ? 'Save all entries as a CSV file in your Downloads folder.'
              : 'Save all ${pluralEntries(count)} as a CSV file in your '
                  'Downloads folder.',
          buttonLabel: 'Export to Downloads',
          onPressed: _busy ? null : _export,
        ),
        const SizedBox(height: 16),
        _ActionCard(
          icon: Icons.file_upload_outlined,
          title: 'Import',
          description: 'Add entries from a CSV file with "timestamp" and '
              '"weight_kg" columns. Existing entries are kept; duplicates '
              'are skipped.',
          buttonLabel: 'Import from CSV',
          onPressed: _busy ? null : _import,
        ),
        const SizedBox(height: 24),
        Text(
          'Your data stays on this device. Height is a setting and is not '
          'included in exports.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
