import '../models/medication_reminder_plan.dart';
import 'medication_reminder_service.dart';

abstract class MedicationNotificationGateway {
  Future<void> scheduleInAppReminder({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  });

  Future<void> scheduleAlarm({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  });

  Future<void> cancelOccurrence(String occurrenceId);
}

class MedicationReminderOrchestrator {
  MedicationReminderOrchestrator({
    required MedicationReminderService reminderService,
    required MedicationNotificationGateway notificationGateway,
  }) : _reminderService = reminderService,
       _notificationGateway = notificationGateway;

  final MedicationReminderService _reminderService;
  final MedicationNotificationGateway _notificationGateway;

  Future<List<ReminderPlan>> scheduleWindow({
    required List<MedicationReminderSchedule> schedules,
    required DateTime from,
    required DateTime until,
    Duration level3Delay = const Duration(minutes: 30),
  }) async {
    final occurrences = _reminderService.computeOccurrences(
      schedules: schedules,
      from: from,
      until: until,
    );

    final plans = <ReminderPlan>[];
    for (final occurrence in occurrences) {
      final plan = _reminderService.buildPlanForOccurrence(
        occurrence,
        level3Delay: level3Delay,
      );
      await _notificationGateway.cancelOccurrence(occurrence.occurrenceId);
      try {
        for (final trigger in plan.triggers) {
          switch (trigger.stage) {
            case ReminderEscalationStage.level1InAppReminder:
              await _notificationGateway.scheduleInAppReminder(
                occurrence: occurrence,
                trigger: trigger,
              );
            case ReminderEscalationStage.level3Alarm:
              await _notificationGateway.scheduleAlarm(
                occurrence: occurrence,
                trigger: trigger,
              );
            case ReminderEscalationStage.none:
              break;
          }
        }
        plans.add(plan);
      } catch (_) {
        await _notificationGateway.cancelOccurrence(occurrence.occurrenceId);
        rethrow;
      }
    }
    return plans;
  }

  Future<EscalationEvaluation> syncEscalation({
    required MedicationDoseOccurrence occurrence,
    required DoseAcknowledgementStatus status,
    required DateTime now,
    ReminderEscalationStage? lastTriggeredStage,
    Duration level3Delay = const Duration(minutes: 30),
  }) async {
    final evaluation = _reminderService.evaluateEscalation(
      occurrence: occurrence,
      status: status,
      now: now,
      lastTriggeredStage: lastTriggeredStage,
      level3Delay: level3Delay,
    );

    if (evaluation.shouldCancelAll) {
      await _notificationGateway.cancelOccurrence(occurrence.occurrenceId);
      return evaluation;
    }

    if (evaluation.shouldTriggerLevel3Alarm) {
      await _notificationGateway.scheduleAlarm(
        occurrence: occurrence,
        trigger: ReminderTrigger(
          triggerId: '${occurrence.occurrenceId}-level3-now',
          stage: ReminderEscalationStage.level3Alarm,
          triggerAt: now,
        ),
      );
    }

    return evaluation;
  }
}
