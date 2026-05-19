import 'dart:io';

import 'package:test/test.dart';
import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';
import 'package:guardian/features/medication/services/medication_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MedicationRepository', () {
    late String dbPath;
    late LocalDb localDb;
    late MedicationRepository repository;

    setUp(() async {
      dbPath = p.join(
        Directory.systemTemp.path,
        'guardian-medication-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      localDb = LocalDb.test(
        databasePath: dbPath,
        databaseFactory: databaseFactoryFfi,
      );
      repository = MedicationRepository(localDb: localDb);
      await localDb.database;
    });

    tearDown(() async {
      await localDb.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });

    test('persists and lists active medication schedules', () async {
      final saved = await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-1',
          name: 'Metformin',
          dosage: '500mg',
          purpose: 'Sugar',
          doseTimes: const <String>['09:00', '21:00'],
          activeDays: const <MedicationWeekday>{
            MedicationWeekday.mon,
            MedicationWeekday.tue,
            MedicationWeekday.wed,
          },
          alarmEscalationEnabled: true,
        ),
      );

      final all = await repository.listActiveSchedules();
      expect(all, hasLength(1));
      expect(all.first.id, 'sched-1');
      expect(all.first.name, 'Metformin');
      expect(saved.createdAt, isNotNull);
      expect(saved.updatedAt, isNotNull);
      expect(saved.updatedAt!.isAfter(saved.createdAt!), isFalse);
    });

    test('creates and marks dose events by date', () async {
      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-2',
          name: 'Aspirin',
          dosage: '1 tablet',
          purpose: null,
          doseTimes: const <String>['08:00'],
          activeDays: const <MedicationWeekday>{MedicationWeekday.fri},
          alarmEscalationEnabled: true,
        ),
      );

      final created = await repository.createDoseEvent(
        scheduleId: 'sched-2',
        scheduledAt: DateTime.utc(2026, 4, 10, 8, 0),
      );
      expect(created.status, MedicationDoseStatus.pending);
      expect(created.escalationLevel, MedicationEscalationLevel.level1);

      final events = await repository.listDoseEventsForDate(
        DateTime.utc(2026, 4, 10, 15, 0),
      );
      expect(events, hasLength(1));
      expect(events.first.scheduleId, 'sched-2');

      final updated = await repository.markDoseEventStatus(
        eventId: created.id,
        status: MedicationDoseStatus.taken,
      );
      expect(updated.status, MedicationDoseStatus.taken);
      expect(updated.actedAt, isNotNull);
    });

    test('persists optional skip reason when dose is skipped', () async {
      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-skip',
          name: 'Aspirin',
          dosage: '1 tablet',
          purpose: null,
          doseTimes: const <String>['08:00'],
          activeDays: const <MedicationWeekday>{MedicationWeekday.fri},
          alarmEscalationEnabled: true,
        ),
      );

      final created = await repository.createDoseEvent(
        scheduleId: 'sched-skip',
        scheduledAt: DateTime.utc(2026, 4, 10, 8, 0),
      );

      final skipped = await repository.markDoseEventStatus(
        eventId: created.id,
        status: MedicationDoseStatus.skipped,
        skipReason: 'Out of supply',
      );

      expect(skipped.status, MedicationDoseStatus.skipped);
      expect(skipped.skipReason, 'Out of supply');
    });

    test('create dose event is idempotent for schedule and slot', () async {
      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-3',
          name: 'Vitamin D',
          dosage: '1 capsule',
          purpose: null,
          doseTimes: const <String>['07:30'],
          activeDays: const <MedicationWeekday>{MedicationWeekday.fri},
          alarmEscalationEnabled: true,
        ),
      );

      final scheduledAt = DateTime.utc(2026, 4, 10, 7, 30);
      final first = await repository.createDoseEvent(
        scheduleId: 'sched-3',
        scheduledAt: scheduledAt,
      );
      final second = await repository.createDoseEvent(
        scheduleId: 'sched-3',
        scheduledAt: scheduledAt,
      );

      expect(second.id, first.id);
      final events = await repository.listDoseEventsForDate(
        DateTime(2026, 4, 10, 12, 0),
      );
      expect(
        events.where((event) => event.scheduleId == 'sched-3'),
        hasLength(1),
      );
    });

    test('can update escalation metadata without changing status', () async {
      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-4',
          name: 'Thyroid tablet',
          dosage: '1 tablet',
          purpose: null,
          doseTimes: const <String>['06:00'],
          activeDays: const <MedicationWeekday>{MedicationWeekday.fri},
          alarmEscalationEnabled: true,
        ),
      );

      final created = await repository.createDoseEvent(
        scheduleId: 'sched-4',
        scheduledAt: DateTime.utc(2026, 4, 10, 6, 0),
      );
      final reminderSentAt = DateTime.utc(2026, 4, 10, 6, 5);

      final updated = await repository.updateDoseEvent(
        eventId: created.id,
        escalationLevel: MedicationEscalationLevel.level3,
        reminderSentAt: reminderSentAt,
      );

      expect(updated.status, MedicationDoseStatus.pending);
      expect(updated.escalationLevel, MedicationEscalationLevel.level3);
      expect(updated.reminderSentAt, reminderSentAt);
      expect(updated.actedAt, isNull);
    });

    test('deletes schedule with hard-delete semantics', () async {
      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'sched-5',
          name: 'Calcium',
          dosage: '1 tablet',
          purpose: null,
          doseTimes: const <String>['10:00'],
          activeDays: const <MedicationWeekday>{MedicationWeekday.fri},
          alarmEscalationEnabled: false,
        ),
      );

      await repository.deleteSchedule('sched-5');

      final all = await repository.listSchedules();
      expect(all.where((schedule) => schedule.id == 'sched-5'), isEmpty);
    });

    test(
      'migrates from v1 pending_events-only schema to medication tables',
      () async {
        await localDb.close();
        await deleteDatabase(dbPath);

        final legacyDb = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute('''
            CREATE TABLE pending_events (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
            },
          ),
        );
        await legacyDb.close();

        await localDb.close();
        localDb = LocalDb.test(
          databasePath: dbPath,
          databaseFactory: databaseFactoryFfi,
        );
        repository = MedicationRepository(localDb: localDb);
        final db = await localDb.database;

        final tables = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'table'
          AND name IN ('medication_schedules', 'medication_dose_events')
      ''');

        expect(
          tables.map((row) => row['name']),
          contains('medication_schedules'),
        );
        expect(
          tables.map((row) => row['name']),
          contains('medication_dose_events'),
        );
      },
    );

    test(
      'v3 migration preserves pending events and adds medication indexes',
      () async {
        await localDb.close();
        await deleteDatabase(dbPath);

        final legacyDb = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, version) async {
              await db.execute('''
            CREATE TABLE pending_events (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
              await db.execute('''
            CREATE TABLE medication_schedules (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL,
              purpose TEXT,
              dose_times TEXT NOT NULL,
              active_days TEXT NOT NULL,
              alarm_escalation_enabled INTEGER NOT NULL DEFAULT 1,
              is_active INTEGER NOT NULL DEFAULT 1,
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
              reminder_sent_at INTEGER,
              acted_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
              await db.insert('pending_events', <String, Object?>{
                'id': 'pending-1',
                'type': 'sync',
                'payload': '{}',
                'created_at': 123,
                'synced': 0,
              });
            },
          ),
        );
        await legacyDb.close();

        await localDb.close();
        localDb = LocalDb.test(
          databasePath: dbPath,
          databaseFactory: databaseFactoryFfi,
        );
        repository = MedicationRepository(localDb: localDb);
        final db = await localDb.database;

        final pending = await db.query('pending_events');
        expect(pending, hasLength(1));

        final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'index'
          AND name IN (
            'idx_medication_dose_events_schedule_id',
            'idx_medication_dose_events_scheduled_at',
            'idx_medication_dose_events_schedule_slot'
          )
      ''');

        expect(
          indexes.map((row) => row['name']),
          contains('idx_medication_dose_events_schedule_id'),
        );
        expect(
          indexes.map((row) => row['name']),
          contains('idx_medication_dose_events_scheduled_at'),
        );
        expect(
          indexes.map((row) => row['name']),
          contains('idx_medication_dose_events_schedule_slot'),
        );
      },
    );

    test(
      'v6 migration drops inactive schedules and keeps active ones',
      () async {
        await localDb.close();
        await deleteDatabase(dbPath);

        final legacyDb = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (db, version) async {
              await db.execute('''
            CREATE TABLE pending_events (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
              await db.execute('''
            CREATE TABLE medication_schedules (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL,
              purpose TEXT,
              dose_times TEXT NOT NULL,
              active_days TEXT NOT NULL,
              alarm_escalation_enabled INTEGER NOT NULL DEFAULT 1,
              is_active INTEGER NOT NULL DEFAULT 1,
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
              reminder_sent_at INTEGER,
              acted_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
              await db.insert('medication_schedules', <String, Object?>{
                'id': 'sched-active',
                'name': 'Metformin',
                'dosage': '500 mg',
                'purpose': 'Sugar',
                'dose_times': '09:00',
                'active_days': 'mon,tue,wed',
                'alarm_escalation_enabled': 1,
                'is_active': 1,
                'created_at': 1,
                'updated_at': 1,
              });
              await db.insert('medication_schedules', <String, Object?>{
                'id': 'sched-inactive',
                'name': 'Old schedule',
                'dosage': '1 tablet',
                'purpose': null,
                'dose_times': '18:00',
                'active_days': 'mon',
                'alarm_escalation_enabled': 1,
                'is_active': 0,
                'created_at': 1,
                'updated_at': 1,
              });
              await db.insert('medication_dose_events', <String, Object?>{
                'id': 'dose-active',
                'schedule_id': 'sched-active',
                'scheduled_at': 1000,
                'status': 'pending',
                'escalation_level': 1,
                'reminder_sent_at': null,
                'acted_at': null,
                'created_at': 1,
                'updated_at': 1,
              });
              await db.insert('medication_dose_events', <String, Object?>{
                'id': 'dose-inactive',
                'schedule_id': 'sched-inactive',
                'scheduled_at': 1001,
                'status': 'pending',
                'escalation_level': 1,
                'reminder_sent_at': null,
                'acted_at': null,
                'created_at': 1,
                'updated_at': 1,
              });
            },
          ),
        );
        await legacyDb.close();

        await localDb.close();
        localDb = LocalDb.test(
          databasePath: dbPath,
          databaseFactory: databaseFactoryFfi,
        );
        repository = MedicationRepository(localDb: localDb);
        final db = await localDb.database;

        final schedules = await db.query('medication_schedules');
        expect(schedules, hasLength(1));
        expect(schedules.single['id'], 'sched-active');

        final doseEvents = await db.query('medication_dose_events');
        expect(doseEvents, hasLength(1));
        expect(doseEvents.single['schedule_id'], 'sched-active');

        final columns = await db.rawQuery(
          "PRAGMA table_info(medication_schedules)",
        );
        final columnNames = columns
            .map((row) => row['name'])
            .whereType<String>()
            .toSet();
        expect(columnNames.contains('is_active'), isFalse);
        expect(columnNames.contains('stop_date'), isTrue);
        expect(columnNames.contains('note'), isTrue);
      },
    );
  });
}
