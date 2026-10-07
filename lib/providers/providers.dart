import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/settings_repository.dart';
import '../data/weight_repository.dart';
import '../domain/stats.dart';
import '../domain/weight_entry.dart';
import '../services/downloads_service.dart';
import '../services/import_service.dart';

// Repositories and services.

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(AppDatabase.instance),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final downloadsServiceProvider = Provider<DownloadsService>(
  (ref) => DownloadsService(),
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(weightRepositoryProvider)),
);

// Entries. Everything below derives from [entriesProvider]; invalidate it
// after any insert/delete/import so every page refreshes.

/// All entries, oldest first.
final entriesProvider = FutureProvider<List<WeightEntry>>(
  (ref) => ref.watch(weightRepositoryProvider).all(),
);

/// Today's entries, newest first.
final todayEntriesProvider = FutureProvider<List<WeightEntry>>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  final today = startOfDay(DateTime.now());
  return entries
      .where((e) => startOfDay(e.localTime) == today)
      .toList()
      .reversed
      .toList();
});

/// Today's average, or `null` if there are no entries today.
final todayAverageProvider = FutureProvider<DailyAverage?>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  return dailyAverageFor(entries, DateTime.now());
});

/// Daily averages for the last 30 days, oldest first.
final last30DaysProvider = FutureProvider<List<DailyAverage>>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  return dailyAveragesForLastDays(entries, DateTime.now());
});

/// Monthly averages for the last 12 months, oldest first.
final last12MonthsProvider = FutureProvider<List<MonthlyAverage>>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  return monthlyAveragesForLastMonths(entries, DateTime.now());
});

/// Weight to use for BMI: today's average, else the most recent day's.
final bmiWeightProvider = FutureProvider<DailyAverage?>((ref) async {
  final entries = await ref.watch(entriesProvider.future);
  return dailyAverageFor(entries, DateTime.now()) ??
      latestDailyAverage(entries);
});

/// Actions that modify entries and refresh dependent providers.
final entryActionsProvider = Provider<EntryActions>((ref) => EntryActions(ref));

class EntryActions {
  EntryActions(this._ref);

  final Ref _ref;

  WeightRepository get _repo => _ref.read(weightRepositoryProvider);

  void _refresh() => _ref.invalidate(entriesProvider);

  /// Saves a new entry stamped with the current time.
  Future<void> add(double weightKg) async {
    await _repo.insert(WeightEntry.at(DateTime.now(), weightKg));
    _refresh();
  }

  Future<void> delete(WeightEntry entry) async {
    await _repo.delete(entry.id!);
    _refresh();
  }

  /// Re-inserts a previously deleted entry (undo).
  Future<void> restore(WeightEntry entry) async {
    await _repo.insert(entry);
    _refresh();
  }

  Future<ImportSummary?> importCsv() async {
    final summary = await _ref.read(importServiceProvider).pickAndImport();
    if (summary != null) _refresh();
    return summary;
  }

  /// Refreshes derived values, e.g. after the date changed.
  void refresh() => _refresh();
}

// Settings.

/// Height in total inches, or `null` if not set.
final heightProvider = AsyncNotifierProvider<HeightNotifier, int?>(
  HeightNotifier.new,
);

class HeightNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() => ref.read(settingsRepositoryProvider).getHeightInches();

  Future<void> setHeight(int totalInches) async {
    await ref.read(settingsRepositoryProvider).setHeightInches(totalInches);
    state = AsyncData(totalInches);
  }
}
