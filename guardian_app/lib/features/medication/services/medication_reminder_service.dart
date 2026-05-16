import '../models/medication_reminder_plan.dart';

class MedicationReminderService {
  List<MedicationDoseOccurrence> computeOccurrences({
    required List<MedicationReminderSchedule> schedules,
    required DateTime from,
    required DateTime until,
  }) {
    final occurrences = <MedicationDoseOccurrence>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final endDate = DateTime(until.year, until.month, until.day);

    while (!cursor.isAfter(endDate)) {
      for (final schedule in schedules) {
        final stopDate = schedule.stopDate;
        if (stopDate != null) {
          final stopDateLocal = DateTime(
            stopDate.year,
            stopDate.month,
            stopDate.day,
          );
          if (cursor.isAfter(stopDateLocal)) {
            continue;
          }
        }

        if (!schedule.activeWeekdays.contains(cursor.weekday)) {
          continue;
        }

        for (final time in schedule.timesOfDay) {
          final scheduledAt = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            time.hour,
            time.minute,
          );
          if (scheduledAt.isBefore(from) || scheduledAt.isAfter(until)) {
            continue;
          }
          occurrences.add(
            MedicationDoseOccurrence(
              occurrenceId:
                  '${schedule.medicationId}-${scheduledAt.millisecondsSinceEpoch}',
              medicationId: schedule.medicationId,
              medicationName: schedule.medicationName,
              dosage: schedule.dosage,
              scheduledAt: scheduledAt,
            ),
          );
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    occurrences.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return occurrences;
  }

  ReminderPlan buildPlanForOccurrence(
    MedicationDoseOccurrence occurrence, {
    Duration level3Delay = const Duration(minutes: 30),
  }) {
    return ReminderPlan(
      occurrence: occurrence,
      triggers: <ReminderTrigger>[
        ReminderTrigger(
          triggerId: '${occurrence.occurrenceId}-level1',
          stage: ReminderEscalationStage.level1InAppReminder,
          triggerAt: occurrence.scheduledAt,
        ),
        ReminderTrigger(
          triggerId: '${occurrence.occurrenceId}-level3',
          stage: ReminderEscalationStage.level3Alarm,
          triggerAt: occurrence.scheduledAt.add(level3Delay),
        ),
      ],
    );
  }

  EscalationEvaluation evaluateEscalation({
    required MedicationDoseOccurrence occurrence,
    required DoseAcknowledgementStatus status,
    required DateTime now,
    ReminderEscalationStage? lastTriggeredStage,
    Duration level3Delay = const Duration(minutes: 30),
  }) {
    if (status != DoseAcknowledgementStatus.pending) {
      return const EscalationEvaluation(
        activeStage: ReminderEscalationStage.none,
        shouldTriggerLevel3Alarm: false,
        shouldCancelAll: true,
      );
    }

    if (now.isBefore(occurrence.scheduledAt)) {
      return const EscalationEvaluation(
        activeStage: ReminderEscalationStage.none,
        shouldTriggerLevel3Alarm: false,
        shouldCancelAll: false,
      );
    }

    final level3At = occurrence.scheduledAt.add(level3Delay);
    if (now.isBefore(level3At)) {
      return const EscalationEvaluation(
        activeStage: ReminderEscalationStage.level1InAppReminder,
        shouldTriggerLevel3Alarm: false,
        shouldCancelAll: false,
      );
    }

    final shouldTrigger =
        lastTriggeredStage != ReminderEscalationStage.level3Alarm;
    return EscalationEvaluation(
      activeStage: ReminderEscalationStage.level3Alarm,
      shouldTriggerLevel3Alarm: shouldTrigger,
      shouldCancelAll: false,
    );
  }
}
