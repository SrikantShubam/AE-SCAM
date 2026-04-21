import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/medication/models/medication_reminder_plan.dart';
import 'package:guardian/features/medication/services/medication_reminder_orchestrator.dart';
import 'package:guardian/features/medication/services/medication_reminder_service.dart';

class _FakeNotificationGateway implements MedicationNotificationGateway {
  final List<ReminderTrigger> reminderTriggers = <ReminderTrigger>[];
  final List<ReminderTrigger> alarmTriggers = <ReminderTrigger>[];
  final List<String> cancelledOccurrenceIds = <String>[];
  bool throwOnAlarmSchedule = false;

  @override
  Future<void> scheduleInAppReminder({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {
    reminderTriggers.add(trigger);
  }

  @override
  Future<void> scheduleAlarm({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {
    if (throwOnAlarmSchedule) {
      throw StateError('alarm scheduling failed');
    }
    alarmTriggers.add(trigger);
  }

  @override
  Future<void> cancelOccurrence(String occurrenceId) async {
    cancelledOccurrenceIds.add(occurrenceId);
  }
}

void main() {
  group('MedicationReminderOrchestrator', () {
    test(
      'schedules level 1 and level 3 triggers for occurrences in a window',
      () async {
        final gateway = _FakeNotificationGateway();
        final orchestrator = MedicationReminderOrchestrator(
          reminderService: MedicationReminderService(),
          notificationGateway: gateway,
        );

        final schedules = <MedicationReminderSchedule>[
          MedicationReminderSchedule(
            medicationId: 'med-1',
            medicationName: 'Amlodipine',
            dosage: '1 tablet',
            activeWeekdays: <int>{DateTime.monday},
            timesOfDay: <ReminderClockTime>[
              ReminderClockTime(hour: 8, minute: 0),
            ],
          ),
        ];

        final expectedOccurrenceId =
            'med-1-${DateTime(2026, 4, 13, 8, 0).toUtc().millisecondsSinceEpoch}';

        final plans = await orchestrator.scheduleWindow(
          schedules: schedules,
          from: DateTime(2026, 4, 13, 7, 30),
          until: DateTime(2026, 4, 13, 8, 30),
        );

        expect(plans, hasLength(1));
        expect(gateway.cancelledOccurrenceIds, <String>[expectedOccurrenceId]);
        expect(gateway.reminderTriggers, hasLength(1));
        expect(gateway.alarmTriggers, hasLength(1));
        expect(
          gateway.reminderTriggers.single.stage,
          ReminderEscalationStage.level1InAppReminder,
        );
        expect(
          gateway.alarmTriggers.single.stage,
          ReminderEscalationStage.level3Alarm,
        );
      },
    );

    test(
      'cancels pending notifications when occurrence is acknowledged',
      () async {
        final gateway = _FakeNotificationGateway();
        final orchestrator = MedicationReminderOrchestrator(
          reminderService: MedicationReminderService(),
          notificationGateway: gateway,
        );

        final occurrence = MedicationDoseOccurrence(
          occurrenceId: 'med-2-202604130800',
          medicationId: 'med-2',
          medicationName: 'Metformin',
          dosage: '500 mg',
          scheduledAt: DateTime(2026, 4, 13, 8, 0),
        );

        final evaluation = await orchestrator.syncEscalation(
          occurrence: occurrence,
          status: DoseAcknowledgementStatus.taken,
          now: DateTime(2026, 4, 13, 8, 5),
        );

        expect(evaluation.shouldCancelAll, isTrue);
        expect(gateway.cancelledOccurrenceIds, <String>[
          occurrence.occurrenceId,
        ]);
      },
    );

    test(
      'triggers an immediate level 3 alarm when a pending dose crosses the threshold',
      () async {
        final gateway = _FakeNotificationGateway();
        final orchestrator = MedicationReminderOrchestrator(
          reminderService: MedicationReminderService(),
          notificationGateway: gateway,
        );

        final occurrence = MedicationDoseOccurrence(
          occurrenceId: 'med-3-202604130800',
          medicationId: 'med-3',
          medicationName: 'Levothyroxine',
          dosage: '50 mcg',
          scheduledAt: DateTime(2026, 4, 13, 8, 0),
        );

        final evaluation = await orchestrator.syncEscalation(
          occurrence: occurrence,
          status: DoseAcknowledgementStatus.pending,
          now: DateTime(2026, 4, 13, 8, 31),
          lastTriggeredStage: ReminderEscalationStage.level1InAppReminder,
        );

        expect(evaluation.activeStage, ReminderEscalationStage.level3Alarm);
        expect(evaluation.shouldTriggerLevel3Alarm, isTrue);
        expect(gateway.alarmTriggers, hasLength(1));
        expect(
          gateway.alarmTriggers.single.triggerAt,
          DateTime(2026, 4, 13, 8, 31),
        );
      },
    );

    test('rolls back occurrence scheduling if alarm scheduling fails', () async {
      final gateway = _FakeNotificationGateway()..throwOnAlarmSchedule = true;
      final orchestrator = MedicationReminderOrchestrator(
        reminderService: MedicationReminderService(),
        notificationGateway: gateway,
      );

      final schedules = <MedicationReminderSchedule>[
        MedicationReminderSchedule(
          medicationId: 'med-1',
          medicationName: 'Amlodipine',
          dosage: '1 tablet',
          activeWeekdays: <int>{DateTime.monday},
          timesOfDay: <ReminderClockTime>[
            ReminderClockTime(hour: 8, minute: 0),
          ],
        ),
      ];

      final expectedOccurrenceId =
          'med-1-${DateTime(2026, 4, 13, 8, 0).toUtc().millisecondsSinceEpoch}';

      await expectLater(
        () => orchestrator.scheduleWindow(
          schedules: schedules,
          from: DateTime(2026, 4, 13, 7, 30),
          until: DateTime(2026, 4, 13, 8, 30),
        ),
        throwsA(isA<StateError>()),
      );

      expect(gateway.reminderTriggers, hasLength(1));
      expect(
        gateway.cancelledOccurrenceIds,
        <String>[expectedOccurrenceId, expectedOccurrenceId],
      );
    });
  });
}
