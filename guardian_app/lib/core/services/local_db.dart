import 'package:path/path.dart' as p;
import 'package:sqflite_common/sql.dart' show ConflictAlgorithm;
import 'package:sqflite_common/sqlite_api.dart';

import '../constants/app_constants.dart';
import 'local_db_platform_stub.dart'
    if (dart.library.ui) 'local_db_platform_flutter.dart'
    as db_platform;

class LocalDb {
  LocalDb._({
    this.databasePath,
    DatabaseFactory? databaseFactory,
    Future<String> Function()? databasesPathProvider,
  }) : _databaseFactory = databaseFactory,
       _databasesPathProvider = databasesPathProvider;

  static final LocalDb instance = LocalDb._();

  factory LocalDb.test({
    required String databasePath,
    DatabaseFactory? databaseFactory,
  }) {
    return LocalDb._(
      databasePath: databasePath,
      databaseFactory: databaseFactory,
    );
  }

  Database? _database;
  final String? databasePath;
  final DatabaseFactory? _databaseFactory;
  final Future<String> Function()? _databasesPathProvider;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final resolvedDatabasePath = await _resolveDatabasePath();
    final databaseFactory =
        _databaseFactory ?? db_platform.databaseFactoryOrNull;
    if (databaseFactory == null) {
      throw UnsupportedError(
        'LocalDb requires a database factory outside Flutter runtime.',
      );
    }

    return databaseFactory.openDatabase(
      resolvedDatabasePath,
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createPendingEventsTable(db);
          await _createMedicationTables(db);
          await _createScamTemplateTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createMedicationTables(db);
          }
          if (oldVersion < 3) {
            await _migrateMedicationTablesToV3(db);
          }
          if (oldVersion < 4) {
            await _createScamTemplateTable(db);
          }
          if (oldVersion < 5) {
            await _migrateScamTemplatesToV5(db);
          }
          if (oldVersion < 6) {
            await _migrateMedicationSchedulesToV6(db);
          }
          if (oldVersion < 7) {
            await _migrateMedicationDoseEventsToV7(db);
          }
        },
      ),
    );
  }

  Future<String> _resolveDatabasePath() async {
    if (databasePath != null) {
      return databasePath!;
    }
    final databasesPathProvider =
        _databasesPathProvider ?? db_platform.getDatabasesPathOrNull;
    if (databasesPathProvider == null) {
      throw UnsupportedError(
        'LocalDb requires a databases path provider outside Flutter runtime.',
      );
    }
    final databasesPath = await databasesPathProvider();
    return p.join(databasesPath, AppConstants.databaseName);
  }

  Future<void> _createPendingEventsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE pending_events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createMedicationTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE medication_schedules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        purpose TEXT,
        dose_times TEXT NOT NULL,
        active_days TEXT NOT NULL,
        alarm_escalation_enabled INTEGER NOT NULL DEFAULT 1,
        stop_date INTEGER,
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_dose_events (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        escalation_level INTEGER NOT NULL DEFAULT 1,
        skip_reason TEXT,
        reminder_sent_at INTEGER,
        acted_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (schedule_id) REFERENCES medication_schedules(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_medication_dose_events_schedule_id ON medication_dose_events(schedule_id)',
    );
    await db.execute(
      'CREATE INDEX idx_medication_dose_events_scheduled_at ON medication_dose_events(scheduled_at)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_medication_dose_events_schedule_slot ON medication_dose_events(schedule_id, scheduled_at)',
    );
  }

  Future<void> _migrateMedicationSchedulesToV6(DatabaseExecutor db) async {
    final columns = await db.rawQuery(
      "PRAGMA table_info(medication_schedules)",
    );
    final hasIsActiveColumn = columns.any(
      (column) => column['name'] == 'is_active',
    );
    if (!hasIsActiveColumn) {
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.execute('''
        CREATE TABLE medication_schedules_v6 (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          dosage TEXT NOT NULL,
          purpose TEXT,
          dose_times TEXT NOT NULL,
          active_days TEXT NOT NULL,
          alarm_escalation_enabled INTEGER NOT NULL DEFAULT 1,
          stop_date INTEGER,
          note TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO medication_schedules_v6 (
          id,
          name,
          dosage,
          purpose,
          dose_times,
          active_days,
          alarm_escalation_enabled,
          stop_date,
          note,
          created_at,
          updated_at
        )
        SELECT
          id,
          name,
          dosage,
          purpose,
          dose_times,
          active_days,
          alarm_escalation_enabled,
          NULL,
          NULL,
          created_at,
          updated_at
        FROM medication_schedules
        WHERE is_active = 1
      ''');
      await db.execute('DROP TABLE medication_schedules');
      await db.execute(
        'ALTER TABLE medication_schedules_v6 RENAME TO medication_schedules',
      );
      await db.execute('''
        DELETE FROM medication_dose_events
        WHERE schedule_id NOT IN (SELECT id FROM medication_schedules)
      ''');
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrateMedicationTablesToV3(DatabaseExecutor db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.execute('''
        CREATE TABLE medication_dose_events_v3 (
          id TEXT PRIMARY KEY,
          schedule_id TEXT NOT NULL,
          scheduled_at INTEGER NOT NULL,
          status TEXT NOT NULL,
          escalation_level INTEGER NOT NULL DEFAULT 1,
          reminder_sent_at INTEGER,
          acted_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (schedule_id) REFERENCES medication_schedules(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT OR REPLACE INTO medication_dose_events_v3 (
          id,
          schedule_id,
          scheduled_at,
          status,
          escalation_level,
          reminder_sent_at,
          acted_at,
          created_at,
          updated_at
        )
        SELECT
          id,
          schedule_id,
          scheduled_at,
          status,
          CASE
            WHEN escalation_level IN (0, 1, 3) THEN escalation_level
            ELSE 1
          END,
          reminder_sent_at,
          acted_at,
          created_at,
          updated_at
        FROM medication_dose_events
      ''');
      await db.execute('DROP TABLE medication_dose_events');
      await db.execute(
        'ALTER TABLE medication_dose_events_v3 RENAME TO medication_dose_events',
      );
      await db.execute(
        'CREATE INDEX idx_medication_dose_events_schedule_id ON medication_dose_events(schedule_id)',
      );
      await db.execute(
        'CREATE INDEX idx_medication_dose_events_scheduled_at ON medication_dose_events(scheduled_at)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX idx_medication_dose_events_schedule_slot ON medication_dose_events(schedule_id, scheduled_at)',
      );
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrateMedicationDoseEventsToV7(DatabaseExecutor db) async {
    try {
      await db.execute(
        'ALTER TABLE medication_dose_events ADD COLUMN skip_reason TEXT',
      );
    } catch (_) {}
  }

  Future<void> _createScamTemplateTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE scam_templates (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        language TEXT NOT NULL,
        regex_patterns TEXT NOT NULL,
        keyword_all TEXT NOT NULL,
        keyword_any_of TEXT NOT NULL,
        precision REAL,
        recall REAL,
        example_matches TEXT NOT NULL DEFAULT '[]',
        notes TEXT,
        severity TEXT NOT NULL,
        reason TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_scam_templates_language_enabled ON scam_templates(language, enabled)',
    );
    await db.execute(
      'CREATE INDEX idx_scam_templates_category ON scam_templates(category)',
    );
  }

  Future<void> _migrateScamTemplatesToV5(DatabaseExecutor db) async {
    try {
      await db.execute('ALTER TABLE scam_templates ADD COLUMN precision REAL');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE scam_templates ADD COLUMN recall REAL');
    } catch (_) {}

    try {
      await db.execute(
        "ALTER TABLE scam_templates ADD COLUMN example_matches TEXT NOT NULL DEFAULT '[]'",
      );
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE scam_templates ADD COLUMN notes TEXT');
    } catch (_) {}
  }

  Future<void> enqueuePendingEvent({
    required String id,
    required String type,
    required String payload,
  }) async {
    final db = await database;
    await db.insert('pending_events', <String, Object>{
      'id': id,
      'type': type,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> listPendingEvents({
    String? type,
    int limit = 50,
  }) async {
    final db = await database;
    return db.query(
      'pending_events',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : <Object?>[type],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> updatePendingEventPayload({
    required String id,
    required String payload,
  }) async {
    final db = await database;
    await db.update(
      'pending_events',
      <String, Object?>{'payload': payload},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> upsertMedicationScheduleRow(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'medication_schedules',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listMedicationScheduleRows() async {
    final db = await database;
    return db.query('medication_schedules', orderBy: 'updated_at DESC');
  }

  Future<int> deleteMedicationScheduleRow(String id) async {
    final db = await database;
    return db.delete(
      'medication_schedules',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<Map<String, Object?>?> getMedicationScheduleById(String id) async {
    final db = await database;
    final rows = await db.query(
      'medication_schedules',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertMedicationDoseEventRow(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'medication_dose_events',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> listMedicationDoseEventRows({
    required int startMs,
    required int endMs,
  }) async {
    final db = await database;
    return db.query(
      'medication_dose_events',
      where: 'scheduled_at >= ? AND scheduled_at < ?',
      whereArgs: <Object?>[startMs, endMs],
      orderBy: 'scheduled_at ASC',
    );
  }

  Future<List<Map<String, Object?>>> listRecentMedicationDoseEventRows({
    int limit = 20,
  }) async {
    final db = await database;
    return db.query(
      'medication_dose_events',
      orderBy: 'scheduled_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> getMedicationDoseEventById(String id) async {
    final db = await database;
    final rows = await db.query(
      'medication_dose_events',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
