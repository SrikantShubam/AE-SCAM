import 'package:flutter/foundation.dart';

import '../../medication/models/medication_reminder_summary.dart';

@immutable
class ChildMedicationAlertItem {
  const ChildMedicationAlertItem({
    required this.title,
    required this.body,
    required this.badge,
    required this.tone,
    this.isPlaceholder = false,
  });

  final String title;
  final String body;
  final String badge;
  final MedicationReminderTone tone;
  final bool isPlaceholder;
}

@immutable
class ChildMedicationAdherenceSummary {
  const ChildMedicationAdherenceSummary({
    required this.statusLabel,
    required this.detail,
    required this.scheduledCount,
    required this.handledCount,
    required this.takenCount,
    required this.skippedCount,
    required this.pendingCount,
    required this.statusTone,
    required this.isLoading,
    required this.hasError,
  });

  final String statusLabel;
  final String detail;
  final int scheduledCount;
  final int handledCount;
  final int takenCount;
  final int skippedCount;
  final int pendingCount;
  final MedicationReminderTone statusTone;
  final bool isLoading;
  final bool hasError;

  const ChildMedicationAdherenceSummary.loading()
    : this(
        statusLabel: 'Checking adherence',
        detail: 'Guardian is loading today\'s medication history.',
        scheduledCount: 0,
        handledCount: 0,
        takenCount: 0,
        skippedCount: 0,
        pendingCount: 0,
        statusTone: MedicationReminderTone.quiet,
        isLoading: true,
        hasError: false,
      );

  const ChildMedicationAdherenceSummary.error()
    : this(
        statusLabel: 'Adherence unavailable',
        detail: 'Guardian could not load the local medication summary yet.',
        scheduledCount: 0,
        handledCount: 0,
        takenCount: 0,
        skippedCount: 0,
        pendingCount: 0,
        statusTone: MedicationReminderTone.quiet,
        isLoading: false,
        hasError: true,
      );

  const ChildMedicationAdherenceSummary.empty()
    : this(
        statusLabel: 'No medicine reminders yet',
        detail: 'Add a medication schedule to begin tracking adherence.',
        scheduledCount: 0,
        handledCount: 0,
        takenCount: 0,
        skippedCount: 0,
        pendingCount: 0,
        statusTone: MedicationReminderTone.quiet,
        isLoading: false,
        hasError: false,
      );

  bool get hasMedication => scheduledCount > 0;
}
