import 'dart:io';

import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/medication/models/medication_reminder_plan.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';
import 'package:guardian/features/medication/services/medication_reminder_orchestrator.dart';
import 'package:guardian/features/medication/services/medication_repository.dart';
import 'package:guardian/features/medication/services/medication_schedule_deletion_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

class _FakeNotificationGateway implements MedicationNotificationGateway {
  final List<String> cancelledOccurrenceIds = <String>[];

  @override
  Future<void> cancelOccurrence(String occurrenceId) async {
    cancelledOccurrenceIds.add(occurrenceId);
  }

  @override
  Future<void> scheduleAlarm({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {}

  @override
  Future<void> scheduleInAppReminder({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MedicationScheduleDeletionService', () {
    late String dbPath;
    late LocalDb localDb;
    late MedicationRepository repository;
    late _FakeNotificationGateway notificationGateway;
    late MedicationScheduleDeletionService deletionService;

    setUp(() async {
      dbPath = p.join(
        Directory.systemTemp.path,
        'guardian-medication-delete-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      localDb = LocalDb.test(
        databasePath: dbPath,
        databaseFactory: databaseFactoryFfi,
      );
      repository = MedicationRepository(localDb: localDb);
      notificationGateway = _FakeNotificationGateway();
      deletionService = MedicationScheduleDeletionService(
        repository: repository,
        notificationGateway: notificationGateway,
      );
      await localDb.database;
    });

    tearDown(() async {
      await localDb.close();
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });

    test(
      'cancels upcoming occurrences before hard-deleting a schedule',
      () async {
        await repository.upsertSchedule(
          MedicationSchedule(
            id: 'sched-delete',
            name: 'Amoxicillin',
            dosage: '1/2 tablet',
            purpose: 'Infection',
            doseTimes: const <String>['09:00', '21:00'],
            activeDays: const <MedicationWeekday>{
              MedicationWeekday.mon,
              MedicationWeekday.tue,
              MedicationWeekday.wed,
              MedicationWeekday.thu,
              MedicationWeekday.fri,
              MedicationWeekday.sat,
              MedicationWeekday.sun,
            },
            alarmEscalationEnabled: true,
            stopDate: DateTime.utc(2026, 4, 16),
            note: 'Take after food',
          ),
        );

        await deletionService.deleteSchedule(
          'sched-delete',
          now: DateTime(2026, 4, 14, 8, 0),
        );

        expect(notificationGateway.cancelledOccurrenceIds, <String>[
          'sched-delete-${DateTime(2026, 4, 14, 9, 0).millisecondsSinceEpoch}',
          'sched-delete-${DateTime(2026, 4, 14, 21, 0).millisecondsSinceEpoch}',
          'sched-delete-${DateTime(2026, 4, 15, 9, 0).millisecondsSinceEpoch}',
          'sched-delete-${DateTime(2026, 4, 15, 21, 0).millisecondsSinceEpoch}',
        ]);
        expect(await repository.listSchedules(), isEmpty);
      },
    );
  });
}
