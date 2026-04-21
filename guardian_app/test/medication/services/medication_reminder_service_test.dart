import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/medication/models/medication_reminder_plan.dart';
import 'package:guardian/features/medication/services/medication_reminder_service.dart';

void main() {
  group('MedicationReminderService', () {
    final service = MedicationReminderService();

    test('computes dose occurrences for active weekdays and times', () {
      final schedules = <MedicationReminderSchedule>[
        MedicationReminderSchedule(
          medicationId: 'med-1',
          medicationName: 'Amlodipine',
          dosage: '1 tablet',
          activeWeekdays: <int>{
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          },
          timesOfDay: <ReminderClockTime>[
            ReminderClockTime(hour: 8, minute: 0),
            ReminderClockTime(hour: 20, minute: 0),
          ],
        ),
      ];

      final from = DateTime(2026, 4, 13, 7, 30); // Monday
      final until = DateTime(2026, 4, 13, 22, 0);

      final occurrences = service.computeOccurrences(
        schedules: schedules,
        from: from,
        until: until,
      );

      expect(occurrences, hasLength(2));
      expect(occurrences.first.scheduledAt, DateTime(2026, 4, 13, 8, 0));
      expect(occurrences.last.scheduledAt, DateTime(2026, 4, 13, 20, 0));
    });

    test('skips already elapsed dose times in the window', () {
      final schedules = <MedicationReminderSchedule>[
        MedicationReminderSchedule(
          medicationId: 'med-2',
          medicationName: 'Metformin',
          dosage: '500 mg',
          activeWeekdays: <int>{DateTime.monday, DateTime.tuesday},
          timesOfDay: <ReminderClockTime>[
            ReminderClockTime(hour: 8, minute: 0),
            ReminderClockTime(hour: 20, minute: 0),
          ],
        ),
      ];

      final from = DateTime(2026, 4, 13, 20, 30); // Monday after both times.
      final until = DateTime(2026, 4, 14, 9, 0);

      final occurrences = service.computeOccurrences(
        schedules: schedules,
        from: from,
        until: until,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.scheduledAt, DateTime(2026, 4, 14, 8, 0));
    });

    test('builds level 1 and level 3 trigger plan for an occurrence', () {
      final occurrence = MedicationDoseOccurrence(
        occurrenceId: 'med-1-202604130800',
        medicationId: 'med-1',
        medicationName: 'Amlodipine',
        dosage: '1 tablet',
        scheduledAt: DateTime(2026, 4, 13, 8, 0),
      );

      final plan = service.buildPlanForOccurrence(
        occurrence,
        level3Delay: const Duration(minutes: 30),
      );

      expect(plan.triggers, hasLength(2));
      expect(
        plan.triggers[0].stage,
        ReminderEscalationStage.level1InAppReminder,
      );
      expect(plan.triggers[0].triggerAt, DateTime(2026, 4, 13, 8, 0));
      expect(plan.triggers[1].stage, ReminderEscalationStage.level3Alarm);
      expect(plan.triggers[1].triggerAt, DateTime(2026, 4, 13, 8, 30));
    });

    test('rejects invalid reminder clock times', () {
      expect(
        () => ReminderClockTime(hour: 24, minute: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects invalid active weekday values', () {
      expect(
        () => MedicationReminderSchedule(
          medicationId: 'bad-med',
          medicationName: 'Bad',
          dosage: '1',
          activeWeekdays: <int>{0},
          timesOfDay: <ReminderClockTime>[
            ReminderClockTime(hour: 8, minute: 0),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'evaluates escalation state for pending doses and promotes to level 3',
      () {
        final occurrence = MedicationDoseOccurrence(
          occurrenceId: 'med-3-202604130800',
          medicationId: 'med-3',
          medicationName: 'Levothyroxine',
          dosage: '50 mcg',
          scheduledAt: DateTime(2026, 4, 13, 8, 0),
        );

        final beforeAlarm = service.evaluateEscalation(
          occurrence: occurrence,
          status: DoseAcknowledgementStatus.pending,
          now: DateTime(2026, 4, 13, 8, 20),
          lastTriggeredStage: ReminderEscalationStage.level1InAppReminder,
          level3Delay: const Duration(minutes: 30),
        );

        expect(
          beforeAlarm.activeStage,
          ReminderEscalationStage.level1InAppReminder,
        );
        expect(beforeAlarm.shouldTriggerLevel3Alarm, isFalse);
        expect(beforeAlarm.shouldCancelAll, isFalse);

        final afterAlarm = service.evaluateEscalation(
          occurrence: occurrence,
          status: DoseAcknowledgementStatus.pending,
          now: DateTime(2026, 4, 13, 8, 31),
          lastTriggeredStage: ReminderEscalationStage.level1InAppReminder,
          level3Delay: const Duration(minutes: 30),
        );

        expect(afterAlarm.activeStage, ReminderEscalationStage.level3Alarm);
        expect(afterAlarm.shouldTriggerLevel3Alarm, isTrue);
        expect(afterAlarm.shouldCancelAll, isFalse);
      },
    );

    test('cancels escalation when dose is taken or skipped', () {
      final occurrence = MedicationDoseOccurrence(
        occurrenceId: 'med-4-202604130800',
        medicationId: 'med-4',
        medicationName: 'Atorvastatin',
        dosage: '10 mg',
        scheduledAt: DateTime(2026, 4, 13, 8, 0),
      );

      final taken = service.evaluateEscalation(
        occurrence: occurrence,
        status: DoseAcknowledgementStatus.taken,
        now: DateTime(2026, 4, 13, 8, 10),
      );
      expect(taken.shouldCancelAll, isTrue);
      expect(taken.activeStage, ReminderEscalationStage.none);

      final skipped = service.evaluateEscalation(
        occurrence: occurrence,
        status: DoseAcknowledgementStatus.skipped,
        now: DateTime(2026, 4, 13, 8, 10),
      );
      expect(skipped.shouldCancelAll, isTrue);
      expect(skipped.activeStage, ReminderEscalationStage.none);
    });
  });
}
