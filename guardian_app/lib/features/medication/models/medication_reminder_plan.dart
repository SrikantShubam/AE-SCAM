class ReminderClockTime {
  ReminderClockTime({required this.hour, required this.minute}) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'must be between 0 and 23');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'must be between 0 and 59');
    }
  }

  final int hour;
  final int minute;
}

class MedicationReminderSchedule {
  MedicationReminderSchedule({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.activeWeekdays,
    required this.timesOfDay,
    this.stopDate,
    this.note,
  }) {
    if (activeWeekdays.isEmpty) {
      throw ArgumentError.value(
        activeWeekdays,
        'activeWeekdays',
        'must contain at least one day',
      );
    }
    if (timesOfDay.isEmpty) {
      throw ArgumentError.value(
        timesOfDay,
        'timesOfDay',
        'must contain at least one reminder time',
      );
    }
    final hasInvalidWeekday = activeWeekdays.any(
      (weekday) => weekday < DateTime.monday || weekday > DateTime.sunday,
    );
    if (hasInvalidWeekday) {
      throw ArgumentError.value(
        activeWeekdays,
        'activeWeekdays',
        'must contain DateTime weekday values',
      );
    }
  }

  final String medicationId;
  final String medicationName;
  final String dosage;
  final Set<int> activeWeekdays;
  final List<ReminderClockTime> timesOfDay;
  final DateTime? stopDate;
  final String? note;
}

class MedicationDoseOccurrence {
  const MedicationDoseOccurrence({
    required this.occurrenceId,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledAt,
    this.note,
  });

  final String occurrenceId;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final DateTime scheduledAt;
  final String? note;
}

enum ReminderEscalationStage { none, level1InAppReminder, level3Alarm }

enum DoseAcknowledgementStatus { pending, taken, skipped }

class ReminderTrigger {
  const ReminderTrigger({
    required this.triggerId,
    required this.stage,
    required this.triggerAt,
  });

  final String triggerId;
  final ReminderEscalationStage stage;
  final DateTime triggerAt;
}

class ReminderPlan {
  const ReminderPlan({required this.occurrence, required this.triggers});

  final MedicationDoseOccurrence occurrence;
  final List<ReminderTrigger> triggers;
}

class EscalationEvaluation {
  const EscalationEvaluation({
    required this.activeStage,
    required this.shouldTriggerLevel3Alarm,
    required this.shouldCancelAll,
  });

  final ReminderEscalationStage activeStage;
  final bool shouldTriggerLevel3Alarm;
  final bool shouldCancelAll;
}
