import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';
import 'package:guardian/features/medication/providers/medication_provider.dart';
import 'package:guardian/features/medication/services/medication_repository.dart';
import 'package:guardian/features/protection/screens/parent_home_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skipForCurrentPlatform = Platform.isWindows;

  const channel = MethodChannel('com.guardian/settings');
  late String dbPath;
  late LocalDb localDb;
  late MedicationRepository repository;

  setUp(() async {
    dbPath = p.join(
      Directory.systemTemp.path,
      'guardian-parent-home-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    localDb = LocalDb.test(databasePath: dbPath);
    repository = MedicationRepository(localDb: localDb);
    await localDb.database;
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await localDb.close();
    await deleteDatabase(dbPath);
  });

  testWidgets(
    'parent home screen shows the redesigned protection summary for inactive monitoring',
    (tester) async {
      final now = DateTime.now();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getPaymentProtectionSnapshot') {
              return <String, dynamic>{
                'serviceEnabled': false,
                'accessibilityHealthEnabled': false,
                'state': 'inactive',
                'reasons': <String>['Live payment protection is off.'],
              };
            }
            return null;
          });

      final weekday = switch (now.weekday) {
        DateTime.monday => MedicationWeekday.mon,
        DateTime.tuesday => MedicationWeekday.tue,
        DateTime.wednesday => MedicationWeekday.wed,
        DateTime.thursday => MedicationWeekday.thu,
        DateTime.friday => MedicationWeekday.fri,
        DateTime.saturday => MedicationWeekday.sat,
        DateTime.sunday => MedicationWeekday.sun,
        _ => MedicationWeekday.mon,
      };
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
        ProviderScope(
          overrides: [
            medicationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: ParentHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protection summary'), findsOneWidget);
      expect(find.text('Guardian payment protection paused'), findsOneWidget);
      expect(find.text('Medicine reminders'), findsOneWidget);
      expect(find.text('Open Android Accessibility settings'), findsOneWidget);
      expect(find.text('Open payment protection'), findsNothing);
      expect(find.text('Mom protected'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Privacy and permissions'),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.text('Privacy and permissions'), findsOneWidget);
    },
    skip: skipForCurrentPlatform,
  );

  testWidgets(
    'opening battery settings from skipped-step banner does not mark completion',
    (tester) async {
      var openBatterySettingsCalls = 0;
      SharedPreferences.setMockInitialValues(<String, Object>{
        'battery_optimization_step_completed': false,
        'battery_optimization_step_skipped': true,
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getPaymentProtectionSnapshot') {
              return <String, dynamic>{
                'serviceEnabled': false,
                'accessibilityHealthEnabled': false,
                'state': 'inactive',
                'reasons': <String>['Live payment protection is off.'],
              };
            }
            if (call.method == 'openBatteryOptimizationSettings') {
              openBatterySettingsCalls += 1;
              return true;
            }
            return null;
          });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            medicationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: ParentHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Finish battery setup for medicine reminders'),
        findsOneWidget,
      );

      await tester.tap(find.text('Open battery optimization settings'));
      await tester.pumpAndSettle();

      expect(openBatterySettingsCalls, 1);
      expect(
        find.text('Finish battery setup for medicine reminders'),
        findsOneWidget,
      );

      final prefsAfterOpen = await SharedPreferences.getInstance();
      expect(
        prefsAfterOpen.getBool('battery_optimization_step_completed'),
        isFalse,
      );
      expect(
        prefsAfterOpen.getBool('battery_optimization_step_skipped'),
        isTrue,
      );

      await tester.tap(find.text('I completed this'));
      await tester.pumpAndSettle();

      expect(
        find.text('Finish battery setup for medicine reminders'),
        findsNothing,
      );

      final prefsAfterComplete = await SharedPreferences.getInstance();
      expect(
        prefsAfterComplete.getBool('battery_optimization_step_completed'),
        isTrue,
      );
      expect(
        prefsAfterComplete.getBool('battery_optimization_step_skipped'),
        isFalse,
      );
    },
    skip: skipForCurrentPlatform,
  );
}
