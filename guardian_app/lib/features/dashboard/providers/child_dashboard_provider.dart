import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../medication/models/medication_dose_event.dart';
import '../../medication/models/medication_reminder_summary.dart';
import '../../medication/models/medication_schedule.dart';
import '../../medication/providers/medication_provider.dart';
import '../../medication/providers/medication_reminder_provider.dart';
import '../../protection/models/protection_alert.dart';
import '../../protection/services/protection_alert_repository.dart';
import '../models/child_dashboard_models.dart';

final childProtectionAlertsProvider =
    FutureProvider<List<GuardianProtectionAlert>>((ref) async {
  return ProtectionAlertRepository.instance.listAlerts(limit: 3);
});

final childMedicationDoseEventsProvider =
    FutureProvider<List<MedicationDoseEvent>>((ref) async {
      final date = ref.watch(selectedMedicationDateProvider);
      final pairId = (await SharedPreferences.getInstance()).getString('pair_id');
      if (pairId == null || pairId.trim().isEmpty || Firebase.apps.isEmpty) {
        final repository = ref.watch(medicationRepositoryProvider);
        return repository.listDoseEventsForDate(date);
      }

      final dayStartLocal = DateTime(date.year, date.month, date.day);
      final dayEndLocal = dayStartLocal.add(const Duration(days: 1));
      final start = Timestamp.fromDate(dayStartLocal.toUtc());
      final end = Timestamp.fromDate(dayEndLocal.toUtc());

      final snapshot = await FirebaseFirestore.instance
          .collection('pairs')
          .doc(pairId)
          .collection('medication_events')
          .where('scheduled_at', isGreaterThanOrEqualTo: start)
          .where('scheduled_at', isLessThan: end)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final scheduledAt =
            (data['scheduled_at'] as Timestamp?)?.toDate().toUtc() ??
            DateTime.now().toUtc();
        final acknowledgedAt =
            (data['acknowledged_at'] as Timestamp?)?.toDate().toUtc();
        return MedicationDoseEvent(
          id: doc.id,
          scheduleId: (data['schedule_id'] as String? ?? '').trim(),
          scheduledAt: scheduledAt,
          status: MedicationDoseStatus.fromCode(
            (data['status'] as String? ?? MedicationDoseStatus.pending.code).trim(),
          ),
          escalationLevel: MedicationEscalationLevel.level1,
          skipReason: (data['skip_reason'] as String?)?.trim(),
          reminderSentAt: null,
          actedAt: acknowledgedAt,
          createdAt: scheduledAt,
          updatedAt: acknowledgedAt ?? scheduledAt,
        );
      }).toList(growable: false);
    });

final childMedicationAdherenceSummaryProvider =
    Provider<ChildMedicationAdherenceSummary>((ref) {
  final schedulesAsync = ref.watch(activeMedicationSchedulesProvider);
  final eventsAsync = ref.watch(childMedicationDoseEventsProvider);
  final selectedDate = ref.watch(selectedMedicationDateProvider);
  final reminderSummary = ref.watch(medicationReminderSummaryProvider);

  if (schedulesAsync.isLoading || eventsAsync.isLoading) {
    return const ChildMedicationAdherenceSummary.loading();
  }

  if (schedulesAsync.hasError || eventsAsync.hasError) {
    return const ChildMedicationAdherenceSummary.error();
  }

  final schedules = schedulesAsync.value ?? const <MedicationSchedule>[];
  final events = eventsAsync.value ?? const <MedicationDoseEvent>[];

  final scheduledCount = _countScheduledDoses(schedules, selectedDate);
  if (scheduledCount == 0) {
    return const ChildMedicationAdherenceSummary.empty();
  }

  final takenCount = events
      .where((event) => event.status == MedicationDoseStatus.taken)
      .length;
  final skippedCount = events
      .where((event) => event.status == MedicationDoseStatus.skipped)
      .length;
  final pendingCount = events
      .where(
        (event) =>
            event.status == MedicationDoseStatus.pending ||
            event.status == MedicationDoseStatus.alarmActive,
      )
      .length;
  final handledCount = takenCount + skippedCount;

  final statusLabel = switch (reminderSummary.statusTone) {
    MedicationReminderTone.overdueAlarm => 'Level 3 alarm active',
    MedicationReminderTone.dueNow => 'Level 1 reminder active',
    MedicationReminderTone.quiet =>
      handledCount == scheduledCount
          ? 'All doses handled today'
          : 'Waiting for the next dose',
  };

  final detail = pendingCount > 0
      ? '$pendingCount still waiting, $takenCount taken, $skippedCount skipped.'
      : handledCount == scheduledCount
      ? 'All scheduled doses for today have been handled on this phone.'
      : 'Guardian is ready for the next scheduled dose on this phone.';

  return ChildMedicationAdherenceSummary(
    statusLabel: statusLabel,
    detail: detail,
    scheduledCount: scheduledCount,
    handledCount: handledCount,
    takenCount: takenCount,
    skippedCount: skippedCount,
    pendingCount: pendingCount,
    statusTone: reminderSummary.statusTone,
    isLoading: false,
    hasError: false,
  );
});

final childMedicationAlertFeedProvider =
    Provider<List<ChildMedicationAlertItem>>((ref) {
  final summary = ref.watch(medicationReminderSummaryProvider);
  final adherence = ref.watch(childMedicationAdherenceSummaryProvider);

  if (adherence.isLoading) {
    return const <ChildMedicationAlertItem>[
      ChildMedicationAlertItem(
        title: 'Loading medicine alerts',
        body: 'Guardian is loading the current medication state.',
        badge: 'Loading',
        tone: MedicationReminderTone.quiet,
        isPlaceholder: true,
      ),
    ];
  }

  if (adherence.hasError) {
    return const <ChildMedicationAlertItem>[
      ChildMedicationAlertItem(
        title: 'Medicine alerts unavailable',
        body: 'Guardian could not load the local medication state yet.',
        badge: 'Needs refresh',
        tone: MedicationReminderTone.quiet,
        isPlaceholder: true,
      ),
    ];
  }

  if (!adherence.hasMedication) {
    return const <ChildMedicationAlertItem>[
      ChildMedicationAlertItem(
        title: 'No medicine alerts yet',
        body: 'Add a schedule to see reminders and local alerts here.',
        badge: 'Local state',
        tone: MedicationReminderTone.quiet,
        isPlaceholder: true,
      ),
    ];
  }

  return <ChildMedicationAlertItem>[
    ChildMedicationAlertItem(
      title: summary.title,
      body: summary.reminderBody,
      badge: summary.statusLabel,
      tone: summary.statusTone,
      isPlaceholder: !summary.canAcknowledge,
    ),
  ];
});

int _countScheduledDoses(
  List<MedicationSchedule> schedules,
  DateTime selectedDate,
) {
  final weekday = _weekdayFromDate(selectedDate);
  var count = 0;

  for (final schedule in schedules) {
    if (!schedule.activeDays.contains(weekday)) {
      continue;
    }
    for (final rawTime in schedule.doseTimes) {
      if (_parseDoseTime(rawTime) != null) {
        count++;
      }
    }
  }

  return count;
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
    _ => throw StateError('Invalid weekday: ${date.weekday}'),
  };
}

(int, int)? _parseDoseTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return (hour, minute);
}
