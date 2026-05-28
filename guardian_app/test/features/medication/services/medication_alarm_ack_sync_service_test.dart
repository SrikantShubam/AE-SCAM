import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';
import 'package:guardian/features/medication/services/medication_alarm_ack_sync_service.dart';
import 'package:guardian/features/medication/services/medication_alarm_platform_bridge.dart';
import 'package:guardian/features/medication/services/medication_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pair_id': 'pair-test-1',
    });
  });

  test('syncPendingAcknowledgements updates local event and mirrors to Firestore', () async {
    final dbFactory = databaseFactoryFfi;
    final dbPath = inMemoryDatabasePath;
    final localDb = LocalDb.test(databasePath: dbPath, databaseFactory: dbFactory);
    final repository = MedicationRepository(localDb: localDb);
    final firestore = FakeFirebaseFirestore();
    final prefs = await SharedPreferences.getInstance();
    final bridge = MedicationAlarmPlatformBridge();

    final schedule = await repository.upsertSchedule(
      MedicationSchedule(
        id: 'sched-1',
        name: 'Metformin',
        dosage: '500 mg',
        purpose: null,
        doseTimes: const <String>['08:00'],
        activeDays: MedicationWeekday.values.toSet(),
        alarmEscalationEnabled: true,
        stopDate: null,
        note: 'After breakfast',
      ),
    );
    final event = await repository.createDoseEvent(
      scheduleId: schedule.id,
      scheduledAt: DateTime.utc(2026, 5, 27, 2),
    );

    final service = MedicationAlarmAckSyncService(
      bridge: bridge,
      repository: repository,
      prefs: prefs,
      firestore: firestore,
      pendingAcknowledgementsProvider: () async => <Map<String, dynamic>>[
        <String, dynamic>{
          'event_id': event.id,
          'schedule_id': schedule.id,
          'medication_name': 'Metformin',
          'scheduled_at_ms': event.scheduledAt.millisecondsSinceEpoch,
          'status': 'taken',
          'skip_reason': '',
          'acknowledged_at_ms': DateTime.utc(2026, 5, 27, 2, 5).millisecondsSinceEpoch,
        },
      ],
    );

    await service.syncPendingAcknowledgements();

    final updated = await repository.updateDoseEvent(eventId: event.id);
    expect(updated.status, MedicationDoseStatus.taken);
    expect(updated.actedAt, isNotNull);

    final remote = await firestore
        .collection('pairs')
        .doc('pair-test-1')
        .collection('medication_events')
        .doc(event.id)
        .get();
    expect(remote.exists, isTrue);
    expect(remote.data()?['schedule_id'], schedule.id);
    expect(remote.data()?['medication_name'], 'Metformin');
    expect(remote.data()?['status'], 'taken');
    expect(remote.data()?['acknowledged_via'], 'alarm');
  });
}
