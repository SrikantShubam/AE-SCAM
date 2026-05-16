import '../models/medication_dose_event.dart';
import '../models/medication_reminder_plan.dart';
import '../models/medication_schedule.dart';
import 'medication_reminder_orchestrator.dart';
import 'medication_repository.dart';

class MedicationReminderDeliveryService {
  const MedicationReminderDeliveryService({
    required MedicationRepository repository,
    required MedicationReminderOrchestrator orchestrator,
  }) : _repository = repository,
       _orchestrator = orchestrator;

  final MedicationRepository _repository;
  final MedicationReminderOrchestrator _orchestrator;

  Future<List<ReminderPlan>> scheduleWindow({
    required DateTime from,
    required DateTime until,
    Duration level3Delay = const Duration(minutes: 30),
  }) async {
    final activeSchedules = await _repository.listActiveSchedules();
    final reminderSchedules = activeSchedules
        .map(_toReminderSchedule)
        .toList(growable: false);

    final plans = await _orchestrator.scheduleWindow(
      schedules: reminderSchedules,
      from: from,
      until: until,
      level3Delay: level3Delay,
    );

    for (final plan in plans) {
      await _repository.createDoseEvent(
        scheduleId: plan.occurrence.medicationId,
        scheduledAt: plan.occurrence.scheduledAt,
      );
    }

    return plans;
  }

  Future<EscalationEvaluation> syncDoseEscalation({
    required MedicationDoseEvent event,
    required DateTime now,
    Duration level3Delay = const Duration(minutes: 30),
  }) async {
    final occurrence = MedicationDoseOccurrence(
      occurrenceId: event.id,
      medicationId: event.scheduleId,
      medicationName: '',
      dosage: '',
      scheduledAt: event.scheduledAt.toLocal(),
    );
    final status = _toAcknowledgementStatus(event.status);
    final previousStage = _toReminderStage(event.escalationLevel);

    final evaluation = await _orchestrator.syncEscalation(
      occurrence: occurrence,
      status: status,
      now: now,
      lastTriggeredStage: previousStage,
      level3Delay: level3Delay,
    );

    if (evaluation.shouldCancelAll) {
      await _repository.updateDoseEvent(
        eventId: event.id,
        escalationLevel: MedicationEscalationLevel.none,
      );
      return evaluation;
    }

    if (evaluation.activeStage == ReminderEscalationStage.level3Alarm &&
        event.escalationLevel != MedicationEscalationLevel.level3) {
      await _repository.updateDoseEvent(
        eventId: event.id,
        status: MedicationDoseStatus.alarmActive,
        escalationLevel: MedicationEscalationLevel.level3,
      );
    }

    return evaluation;
  }

  MedicationReminderSchedule _toReminderSchedule(MedicationSchedule schedule) {
    final weekdays = schedule.activeDays
        .map(
          (day) => switch (day) {
            MedicationWeekday.mon => DateTime.monday,
            MedicationWeekday.tue => DateTime.tuesday,
            MedicationWeekday.wed => DateTime.wednesday,
            MedicationWeekday.thu => DateTime.thursday,
            MedicationWeekday.fri => DateTime.friday,
            MedicationWeekday.sat => DateTime.saturday,
            MedicationWeekday.sun => DateTime.sunday,
          },
        )
        .toSet();

    final times = schedule.doseTimes
        .map((timeString) {
          final parts = timeString.split(':');
          if (parts.length != 2) {
            return null;
          }
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null || minute == null) {
            return null;
          }
          return ReminderClockTime(hour: hour, minute: minute);
        })
        .whereType<ReminderClockTime>()
        .toList(growable: false);

    return MedicationReminderSchedule(
      medicationId: schedule.id,
      medicationName: schedule.name,
      dosage: schedule.dosage,
      activeWeekdays: weekdays,
      timesOfDay: times,
      stopDate: schedule.stopDate?.toLocal(),
    );
  }

  DoseAcknowledgementStatus _toAcknowledgementStatus(
    MedicationDoseStatus status,
  ) {
    return switch (status) {
      MedicationDoseStatus.pending ||
      MedicationDoseStatus.alarmActive => DoseAcknowledgementStatus.pending,
      MedicationDoseStatus.taken => DoseAcknowledgementStatus.taken,
      MedicationDoseStatus.skipped => DoseAcknowledgementStatus.skipped,
    };
  }

  ReminderEscalationStage _toReminderStage(MedicationEscalationLevel level) {
    return switch (level) {
      MedicationEscalationLevel.none => ReminderEscalationStage.none,
      MedicationEscalationLevel.level1 =>
        ReminderEscalationStage.level1InAppReminder,
      MedicationEscalationLevel.level3 => ReminderEscalationStage.level3Alarm,
    };
  }
}
