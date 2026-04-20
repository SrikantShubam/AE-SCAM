import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medication_dose_event.dart';
import '../models/medication_reminder_summary.dart';
import '../models/medication_schedule.dart';
import 'medication_provider.dart';

final medicationReminderSnoozeProvider =
    NotifierProvider<MedicationReminderSnoozeNotifier, Map<String, DateTime>>(
      MedicationReminderSnoozeNotifier.new,
    );

final medicationReminderSummaryProvider =
    Provider<MedicationReminderSummary>((ref) {
  final schedulesAsync = ref.watch(activeMedicationSchedulesProvider);
  final eventsAsync = ref.watch(medicationDoseEventsForSelectedDateProvider);
  final selectedDate = ref.watch(selectedMedicationDateProvider);
  final snoozes = ref.watch(medicationReminderSnoozeProvider);
  final now = DateTime.now();

  if (schedulesAsync.hasError || eventsAsync.hasError) {
    return const MedicationReminderSummary(
      title: 'Medicine reminders are unavailable',
      dosage: 'Check again',
      nextDoseLabel: 'Unable to load',
      statusLabel: 'Needs refresh',
      statusTone: MedicationReminderTone.quiet,
      reminderBody: 'Guardian could not load today\'s medicine plan yet.',
    );
  }

  if (schedulesAsync.isLoading || eventsAsync.isLoading) {
    return const MedicationReminderSummary(
      title: 'Medicine reminders',
      dosage: 'Loading',
      nextDoseLabel: 'Checking today',
      statusLabel: 'Preparing',
      statusTone: MedicationReminderTone.quiet,
      reminderBody: 'Guardian is loading today\'s medicine plan.',
    );
  }

  final schedules = schedulesAsync.value ?? const <MedicationSchedule>[];
  final events = eventsAsync.value ?? const <MedicationDoseEvent>[];
  if (schedules.isEmpty) {
    return const MedicationReminderSummary(
      title: 'No medicine reminders yet',
      dosage: 'Add medicines',
      nextDoseLabel: 'Nothing scheduled',
      statusLabel: 'Quiet',
      statusTone: MedicationReminderTone.quiet,
      reminderBody: 'Add a medicine schedule to start daily reminders and alarms.',
    );
  }

  final scheduleById = <String, MedicationSchedule>{
    for (final schedule in schedules) schedule.id: schedule,
  };
  final eventByOccurrenceKey = <String, MedicationDoseEvent>{
    for (final event in events)
      medicationReminderOccurrenceKey(
        scheduleId: event.scheduleId,
        scheduledAt: event.scheduledAt.toLocal(),
      ): event,
  };

  final candidates = _buildCandidateOccurrences(
    schedules: schedules,
    selectedDate: selectedDate,
    days: 7,
    eventByOccurrenceKey: eventByOccurrenceKey,
    snoozes: snoozes,
  );
  final currentCandidate = candidates
      .where((candidate) => !candidate.isAcknowledged && !candidate.scheduledAt.isAfter(now))
      .toList(growable: false)
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  if (currentCandidate.isNotEmpty) {
    final candidate = currentCandidate.first;
    final snoozedUntil = candidate.snoozedUntil;
    if (snoozedUntil != null && snoozedUntil.isAfter(now)) {
      return MedicationReminderSummary(
        title: candidate.schedule.name,
        dosage: candidate.schedule.dosage,
        nextDoseLabel: 'Reminds again at ${_formatTime(snoozedUntil)}',
        statusLabel: 'Snoozed',
        statusTone: MedicationReminderTone.quiet,
        reminderBody:
            'Guardian paused this reminder briefly and will bring it back on this phone.',
        scheduleId: candidate.schedule.id,
        scheduledAt: candidate.scheduledAt,
        eventId: candidate.event?.id,
      );
    }

    final minutesOverdue = now.difference(candidate.scheduledAt).inMinutes;
    final shouldAlarm =
        candidate.event?.status == MedicationDoseStatus.alarmActive ||
        (candidate.schedule.alarmEscalationEnabled && minutesOverdue >= 30) ||
        candidate.event?.escalationLevel == MedicationEscalationLevel.level3;

    return MedicationReminderSummary(
      title: candidate.schedule.name,
      dosage: candidate.schedule.dosage,
      nextDoseLabel: shouldAlarm ? 'Overdue by ${minutesOverdue} min' : 'Due now',
      statusLabel: shouldAlarm ? 'Level 3 alarm' : 'Level 1 reminder',
      statusTone: shouldAlarm
          ? MedicationReminderTone.overdueAlarm
          : MedicationReminderTone.dueNow,
      reminderBody: shouldAlarm
          ? 'This dose is overdue. Please take it now or confirm that it was skipped.'
          : 'It is time for your medicine. Please take it now.',
      scheduleId: candidate.schedule.id,
      scheduledAt: candidate.scheduledAt,
      eventId: candidate.event?.id,
    );
  }

  final nextOccurrence = candidates
      .where(
        (candidate) =>
            !candidate.isAcknowledged &&
            candidate.scheduledAt.isAfter(now) &&
            (candidate.snoozedUntil == null || !candidate.snoozedUntil!.isAfter(candidate.scheduledAt)),
      )
      .toList(growable: false)
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (nextOccurrence.isEmpty) {
    return const MedicationReminderSummary(
      title: 'Medicine reminders',
      dosage: 'No active times',
      nextDoseLabel: 'Nothing due today',
      statusLabel: 'Quiet',
      statusTone: MedicationReminderTone.quiet,
      reminderBody: 'Guardian did not find another active medicine time yet.',
    );
  }

  final candidate = nextOccurrence.first;
  return MedicationReminderSummary(
    title: candidate.schedule.name,
    dosage: candidate.schedule.dosage,
    nextDoseLabel: _formatOccurrenceLabel(candidate.scheduledAt, now),
    statusLabel: 'Next reminder',
    statusTone: MedicationReminderTone.quiet,
    reminderBody:
        'Guardian will show a reminder at the next medicine time and raise an alarm if it stays unconfirmed.',
    scheduleId: candidate.schedule.id,
    scheduledAt: candidate.scheduledAt,
    eventId: candidate.event?.id,
  );
});

class _MedicationReminderCandidate {
  const _MedicationReminderCandidate({
    required this.schedule,
    required this.scheduledAt,
    required this.event,
    required this.snoozedUntil,
  });

  final MedicationSchedule schedule;
  final DateTime scheduledAt;
  final MedicationDoseEvent? event;
  final DateTime? snoozedUntil;

  bool get isAcknowledged =>
      event?.status == MedicationDoseStatus.taken ||
      event?.status == MedicationDoseStatus.skipped;
}

List<_MedicationReminderCandidate> _buildCandidateOccurrences({
  required List<MedicationSchedule> schedules,
  required DateTime selectedDate,
  required int days,
  required Map<String, MedicationDoseEvent> eventByOccurrenceKey,
  required Map<String, DateTime> snoozes,
}) {
  final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final candidates = <_MedicationReminderCandidate>[];

  for (var offset = 0; offset < days; offset++) {
    final day = start.add(Duration(days: offset));
    for (final schedule in schedules) {
      if (!schedule.activeDays.contains(_weekdayFromDate(day))) {
        continue;
      }
      for (final rawTime in schedule.doseTimes) {
        final time = _parseDoseTime(rawTime);
        if (time == null) {
          continue;
        }
        final scheduledAt = DateTime(
          day.year,
          day.month,
          day.day,
          time.$1,
          time.$2,
        );
        final key = medicationReminderOccurrenceKey(
          scheduleId: schedule.id,
          scheduledAt: scheduledAt,
        );
        candidates.add(
          _MedicationReminderCandidate(
            schedule: schedule,
            scheduledAt: scheduledAt,
            event: eventByOccurrenceKey[key],
            snoozedUntil: snoozes[key],
          ),
        );
      }
    }
  }

  candidates.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return candidates;
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

String _formatOccurrenceLabel(DateTime scheduledAt, DateTime now) {
  final dayLabel = _sameDate(scheduledAt, now)
      ? 'Today'
      : (_sameDate(scheduledAt, now.add(const Duration(days: 1)))
            ? 'Tomorrow'
            : '${scheduledAt.day}/${scheduledAt.month}');
  return '$dayLabel at ${_formatTime(scheduledAt)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String medicationReminderOccurrenceKey({
  required String scheduleId,
  required DateTime scheduledAt,
}) {
  return '$scheduleId-${scheduledAt.toUtc().millisecondsSinceEpoch}';
}

class MedicationReminderSnoozeNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => <String, DateTime>{};

  void snooze({
    required String scheduleId,
    required DateTime scheduledAt,
    Duration duration = const Duration(minutes: 10),
  }) {
    final key = medicationReminderOccurrenceKey(
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
    );
    state = <String, DateTime>{
      ...state,
      key: DateTime.now().add(duration),
    };
  }

  void clear({
    required String scheduleId,
    required DateTime scheduledAt,
  }) {
    final key = medicationReminderOccurrenceKey(
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
    );
    final next = <String, DateTime>{...state};
    next.remove(key);
    state = next;
  }
}
