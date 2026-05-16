import '../../../core/services/local_db.dart';
import '../models/medication_dose_event.dart';
import '../models/medication_schedule.dart';

class MedicationRepository {
  const MedicationRepository({required this.localDb});

  final LocalDb localDb;

  Future<MedicationSchedule> upsertSchedule(MedicationSchedule schedule) async {
    final now = DateTime.now().toUtc();
    final existing = await localDb.getMedicationScheduleById(schedule.id);
    final createdAt = existing == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(
            (existing['created_at'] as num).toInt(),
            isUtc: true,
          );

    final row = schedule.toDbRow(createdAt: createdAt, updatedAt: now);
    await localDb.upsertMedicationScheduleRow(row);
    return MedicationSchedule.fromDbRow(row);
  }

  Future<List<MedicationSchedule>> listSchedules() async {
    final rows = await localDb.listMedicationScheduleRows();
    return rows.map(MedicationSchedule.fromDbRow).toList(growable: false);
  }

  Future<List<MedicationSchedule>> listActiveSchedules() async {
    return listSchedules();
  }

  Future<MedicationSchedule?> getScheduleById(String scheduleId) async {
    final row = await localDb.getMedicationScheduleById(scheduleId);
    if (row == null) {
      return null;
    }
    return MedicationSchedule.fromDbRow(row);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final deletedCount = await localDb.deleteMedicationScheduleRow(scheduleId);
    if (deletedCount == 0) {
      throw StateError('Medication schedule not found: $scheduleId');
    }
  }

  Future<MedicationDoseEvent> createDoseEvent({
    required String scheduleId,
    required DateTime scheduledAt,
  }) async {
    final normalizedScheduledAt = scheduledAt.toUtc();
    final eventId = _doseEventId(
      scheduleId: scheduleId,
      scheduledAt: normalizedScheduledAt,
    );
    final existing = await localDb.getMedicationDoseEventById(eventId);
    if (existing != null) {
      return MedicationDoseEvent.fromDbRow(existing);
    }

    final now = DateTime.now().toUtc();
    final event = MedicationDoseEvent(
      id: eventId,
      scheduleId: scheduleId,
      scheduledAt: normalizedScheduledAt,
      status: MedicationDoseStatus.pending,
      escalationLevel: MedicationEscalationLevel.level1,
      reminderSentAt: null,
      actedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    await localDb.upsertMedicationDoseEventRow(event.toDbRow());
    return event;
  }

  Future<List<MedicationDoseEvent>> listDoseEventsForDate(DateTime date) async {
    final localDate = date.toLocal();
    final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = await localDb.listMedicationDoseEventRows(
      startMs: dayStart.toUtc().millisecondsSinceEpoch,
      endMs: dayEnd.toUtc().millisecondsSinceEpoch,
    );
    return rows.map(MedicationDoseEvent.fromDbRow).toList(growable: false);
  }

  Future<MedicationDoseEvent> markDoseEventStatus({
    required String eventId,
    required MedicationDoseStatus status,
  }) async {
    final actedAt = switch (status) {
      MedicationDoseStatus.pending || MedicationDoseStatus.alarmActive => null,
      MedicationDoseStatus.taken ||
      MedicationDoseStatus.skipped => DateTime.now().toUtc(),
    };
    return updateDoseEvent(eventId: eventId, status: status, actedAt: actedAt);
  }

  Future<MedicationDoseEvent> updateDoseEvent({
    required String eventId,
    MedicationDoseStatus? status,
    MedicationEscalationLevel? escalationLevel,
    DateTime? reminderSentAt,
    DateTime? actedAt,
  }) async {
    final existing = await localDb.getMedicationDoseEventById(eventId);
    if (existing == null) {
      throw StateError('Dose event not found: $eventId');
    }
    final now = DateTime.now().toUtc();
    final updated = MedicationDoseEvent.fromDbRow(existing).copyWith(
      status: status,
      escalationLevel: escalationLevel,
      reminderSentAt: reminderSentAt,
      actedAt: actedAt,
      updatedAt: now,
    );
    await localDb.upsertMedicationDoseEventRow(updated.toDbRow());
    return updated;
  }

  String _doseEventId({
    required String scheduleId,
    required DateTime scheduledAt,
  }) {
    return 'dose-$scheduleId-${scheduledAt.millisecondsSinceEpoch}';
  }
}
