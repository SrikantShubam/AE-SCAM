import 'package:flutter/material.dart';

enum MedicationReminderTone {
  dueNow,
  overdueAlarm,
  quiet,
}

@immutable
class MedicationReminderSummary {
  const MedicationReminderSummary({
    required this.title,
    required this.dosage,
    required this.nextDoseLabel,
    required this.statusLabel,
    required this.statusTone,
    required this.reminderBody,
    this.scheduleId,
    this.scheduledAt,
    this.eventId,
  });

  final String title;
  final String dosage;
  final String nextDoseLabel;
  final String statusLabel;
  final MedicationReminderTone statusTone;
  final String reminderBody;
  final String? scheduleId;
  final DateTime? scheduledAt;
  final String? eventId;

  bool get isAlarmActive => statusTone == MedicationReminderTone.overdueAlarm;
  bool get canAcknowledge => scheduleId != null && scheduledAt != null;
}
