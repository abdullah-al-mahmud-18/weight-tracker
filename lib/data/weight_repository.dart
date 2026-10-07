import 'package:sqflite/sqflite.dart';

import '../domain/weight_entry.dart';
import 'app_database.dart';

/// Outcome of a bulk import.
class ImportCounts {
  const ImportCounts({required this.inserted, required this.duplicates});
  final int inserted;
  final int duplicates;
}

/// CRUD and range queries for weight entries.
class WeightRepository {
  WeightRepository(this._appDb);

  final AppDatabase _appDb;

  static const String _table = AppDatabase.entriesTable;

  Future<Database> get _db => _appDb.database;

  static WeightEntry _fromRow(Map<String, Object?> row) => WeightEntry(
        id: row['id'] as int,
        timestampMs: row['timestamp_ms'] as int,
        weightKg: (row['weight_kg'] as num).toDouble(),
      );

  static Map<String, Object?> _toRow(WeightEntry e) => {
        if (e.id != null) 'id': e.id,
        'timestamp_ms': e.timestampMs,
        'weight_kg': e.weightKg,
      };

  /// Inserts [entry] and returns its new id. Duplicates are ignored.
  Future<int> insert(WeightEntry entry) async {
    final db = await _db;
    return db.insert(
      _table,
      _toRow(entry),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Deletes the entry with [id].
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// All entries, oldest first.
  Future<List<WeightEntry>> all() async {
    final db = await _db;
    final rows = await db.query(_table, orderBy: 'timestamp_ms ASC, id ASC');
    return rows.map(_fromRow).toList();
  }

  /// Entries with `start <= timestamp < end`, oldest first.
  Future<List<WeightEntry>> between(DateTime start, DateTime end) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'timestamp_ms >= ? AND timestamp_ms < ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp_ms ASC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Inserts [entries] with `INSERT OR IGNORE` in one transaction.
  Future<ImportCounts> insertAllIgnoringDuplicates(
    List<WeightEntry> entries,
  ) async {
    final db = await _db;
    return db.transaction((txn) async {
      final before = await _count(txn);
      final batch = txn.batch();
      for (final e in entries) {
        batch.rawInsert(
          'INSERT OR IGNORE INTO $_table (timestamp_ms, weight_kg) '
          'VALUES (?, ?)',
          [e.timestampMs, e.weightKg],
        );
      }
      await batch.commit(noResult: true);
      final inserted = await _count(txn) - before;
      return ImportCounts(
        inserted: inserted,
        duplicates: entries.length - inserted,
      );
    });
  }

  Future<int> _count(DatabaseExecutor db) async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_table')) ??
      0;
}
