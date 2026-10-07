import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the app's SQLite database and applies schema migrations.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String fileName = 'weight_tracker.db';
  static const String entriesTable = 'entries';

  /// Migration scripts; index `i` upgrades the schema from version `i` to
  /// `i + 1`. To migrate, append a step — the version follows automatically.
  static final List<Future<void> Function(DatabaseExecutor db)> _migrations = [
    _createV1,
  ];

  static int get version => _migrations.length;

  Future<Database>? _db;

  /// The opened database (opened lazily, once).
  Future<Database> get database => _db ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      path,
      version: version,
      onCreate: (db, newVersion) => _migrate(db, 0, newVersion),
      onUpgrade: _migrate,
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await _migrations[v](db);
    }
  }

  static Future<void> _createV1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $entriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp_ms INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        UNIQUE(timestamp_ms, weight_kg)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entries_timestamp ON $entriesTable(timestamp_ms)',
    );
  }
}
