import '../models/medication_reminder_plan.dart';
import '../models/medication_schedule.dart';
import 'medication_reminder_orchestrator.dart';
import 'medication_reminder_service.dart';
import 'medication_repository.dart';

class MedicationScheduleDeletionService {
  MedicationScheduleDeletionService({
    required MedicationRepository repository,
    required MedicationNotificationGateway notificationGateway,
    MedicationReminderService? reminderService,
  }) : _repository = repository,
       _notificationGateway = notificationGateway,
       _reminderService = reminderService ?? MedicationReminderService();

  final MedicationRepository _repository;
  final MedicationNotificationGateway _notificationGateway;
  final MedicationReminderService _reminderService;

  Future<void> deleteSchedule(
    String scheduleId, {
    DateTime? now,
    Duration schedulingWindow = const Duration(days: 2),
    Duration backfillWindow = const Duration(minutes: 1),
  }) async {
    final schedule = await _repository.getScheduleById(scheduleId);
    if (schedule == null) {
      throw StateError('Medication schedule not found: $scheduleId');
    }

    final windowStart = (now ?? DateTime.now()).toLocal().subtract(
      backfillWindow,
    );
    final windowEnd = windowStart.add(schedulingWindow).add(backfillWindow);
    final reminderSchedule = _toReminderSchedule(schedule);
    final occurrences = _reminderService.computeOccurrences(
      schedules: <MedicationReminderSchedule>[reminderSchedule],
      from: windowStart,
      until: windowEnd,
    );

    for (final occurrence in occurrences) {
      await _notificationGateway.cancelOccurrence(occurrence.occurrenceId);
    }

    await _repository.deleteSchedule(scheduleId);
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
}
