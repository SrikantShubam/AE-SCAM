import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/dashboard/providers/child_dashboard_provider.dart';
import 'package:guardian/features/dashboard/screens/child_dashboard_screen.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';
import 'package:guardian/features/medication/providers/medication_provider.dart';
import 'package:guardian/features/medication/services/medication_repository.dart';
import 'package:guardian/features/protection/models/protection_alert.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skipForCurrentPlatform = Platform.isWindows;

  late String dbPath;
  late LocalDb localDb;
  late MedicationRepository repository;

  setUp(() async {
    dbPath = p.join(
      Directory.systemTemp.path,
      'guardian-child-dashboard-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    localDb = LocalDb.test(databasePath: dbPath);
    repository = MedicationRepository(localDb: localDb);
    await localDb.database;
  });

  tearDown(() async {
    await localDb.close();
    await deleteDatabase(dbPath);
  });

  Widget _wrap({
    required Widget child,
    required Future<List<GuardianProtectionAlert>> Function() alertsLoader,
  }) {
    return ProviderScope(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(repository),
        childProtectionAlertsProvider.overrideWith((ref) => alertsLoader()),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('shows empty local-first child dashboard states', (tester) async {
    await tester.pumpWidget(
      _wrap(
        child: const ChildDashboardScreen(),
        alertsLoader: () async => const <GuardianProtectionAlert>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Child dashboard'), findsOneWidget);
    expect(find.text('No medicine reminders yet'), findsWidgets);
    expect(
      find.text('No recent payment protection alerts yet.'),
      findsOneWidget,
    );
    expect(find.text('Adherence summary'), findsOneWidget);
  }, skip: skipForCurrentPlatform);

  testWidgets(
    'shows due-now medication status and local adherence details',
    (tester) async {
      final now = DateTime.now();
      final weekday = _weekdayFromDate(now);
      final scheduledAt = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).subtract(const Duration(minutes: 5));

      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'schedule-1',
          name: 'Morning blood pressure tablet',
          dosage: '1 tablet',
          purpose: 'Blood pressure',
          doseTimes: <String>[
            '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
          ],
          activeDays: <MedicationWeekday>{weekday},
          alarmEscalationEnabled: true,
        ),
      );
      final event = await repository.createDoseEvent(
        scheduleId: 'schedule-1',
        scheduledAt: scheduledAt,
      );
      await repository.updateDoseEvent(
        eventId: event.id,
        status: MedicationDoseStatus.pending,
        escalationLevel: MedicationEscalationLevel.level1,
      );

      await tester.pumpWidget(
        _wrap(
          child: const ChildDashboardScreen(),
          alertsLoader: () async => const <GuardianProtectionAlert>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current medication status'), findsOneWidget);
      expect(find.text('Level 1 reminder'), findsWidgets);
      expect(find.text('Due now'), findsWidgets);
      expect(find.textContaining('still waiting'), findsOneWidget);
      expect(find.text('Recent medication alerts'), findsOneWidget);
    },
    skip: skipForCurrentPlatform,
  );

  testWidgets(
    'shows overdue alarm state and payment protection activity',
    (tester) async {
      final now = DateTime.now();
      final weekday = _weekdayFromDate(now);
      final scheduledAt = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).subtract(const Duration(minutes: 30));

      await repository.upsertSchedule(
        MedicationSchedule(
          id: 'schedule-2',
          name: 'Evening diabetes medicine',
          dosage: '2 tablets',
          purpose: 'Blood sugar',
          doseTimes: <String>[
            '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}',
          ],
          activeDays: <MedicationWeekday>{weekday},
          alarmEscalationEnabled: true,
        ),
      );
      final event = await repository.createDoseEvent(
        scheduleId: 'schedule-2',
        scheduledAt: scheduledAt,
      );
      await repository.updateDoseEvent(
        eventId: event.id,
        status: MedicationDoseStatus.alarmActive,
        escalationLevel: MedicationEscalationLevel.level3,
      );

      final alert = GuardianProtectionAlert(
        id: 'alert-1',
        type: GuardianProtectionAlert.typeChildAlert,
        status: GuardianProtectionAlertStatus.queued,
        state: 'red',
        createdAt: DateTime.now(),
        synced: false,
        title: 'Payment warning recorded',
        body: 'Guardian recorded a stronger payment-risk event.',
        reason: 'High amount and unfamiliar recipient',
        appLabel: 'PhonePe',
        amountHint: 'Rs 4,000',
        recipientHint: 'Rajesh',
      );

      await tester.pumpWidget(
        _wrap(
          child: const ChildDashboardScreen(),
          alertsLoader: () async => <GuardianProtectionAlert>[alert],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 3 alarm active'), findsOneWidget);
      expect(find.text('Alarm on this phone'), findsWidgets);
      expect(find.text('Payment protection activity'), findsOneWidget);
      expect(find.text('Payment warning recorded'), findsOneWidget);
    },
    skip: skipForCurrentPlatform,
  );
}

MedicationWeekday _weekdayFromDate(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => MedicationWeekday.mon,
    DateTime.tuesday => MedicationWeekday.tue,
    DateTime.wednesday => MedicationWeekday.wed,
    DateTime.thursday => MedicationWeekday.thu,
    DateTime.friday => MedicationWeekday.fri,
    DateTime.saturday => MedicationWeekday.sat,
    DateTime.sunday => MedicationWeekday.sun,
    _ => MedicationWeekday.mon,
  };
}
