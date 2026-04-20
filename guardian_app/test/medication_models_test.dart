import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';

void main() {
  test('medication schedule supports db round-trip serialization', () {
    final now = DateTime.utc(2026, 4, 10, 8, 30);
    const schedule = MedicationSchedule(
      id: 'schedule-1',
      name: 'Amlodipine',
      dosage: '1 tablet',
      purpose: 'Blood pressure',
      doseTimes: <String>['08:00', '20:00'],
      activeDays: <MedicationWeekday>{
        MedicationWeekday.mon,
        MedicationWeekday.tue,
        MedicationWeekday.wed,
        MedicationWeekday.thu,
        MedicationWeekday.fri,
      },
      alarmEscalationEnabled: true,
      isActive: true,
    );

    final row = schedule.toDbRow(createdAt: now, updatedAt: now);
    final restored = MedicationSchedule.fromDbRow(row);

    expect(restored.id, schedule.id);
    expect(restored.name, schedule.name);
    expect(restored.dosage, schedule.dosage);
    expect(restored.purpose, schedule.purpose);
    expect(restored.doseTimes, schedule.doseTimes);
    expect(restored.activeDays, schedule.activeDays);
    expect(restored.alarmEscalationEnabled, isTrue);
    expect(restored.isActive, isTrue);
    expect(restored.createdAt, now);
    expect(restored.updatedAt, now);
  });

  test('medication dose event supports db round-trip serialization', () {
    final now = DateTime.utc(2026, 4, 10, 9, 0);
    final event = MedicationDoseEvent(
      id: 'dose-1',
      scheduleId: 'schedule-1',
      scheduledAt: DateTime.utc(2026, 4, 10, 8, 0),
      status: MedicationDoseStatus.pending,
      escalationLevel: MedicationEscalationLevel.level1,
      reminderSentAt: now,
      actedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    final row = event.toDbRow();
    final restored = MedicationDoseEvent.fromDbRow(row);

    expect(restored.id, event.id);
    expect(restored.scheduleId, event.scheduleId);
    expect(restored.scheduledAt, event.scheduledAt);
    expect(restored.status, event.status);
    expect(restored.escalationLevel, event.escalationLevel);
    expect(restored.reminderSentAt, event.reminderSentAt);
    expect(restored.actedAt, event.actedAt);
    expect(restored.createdAt, event.createdAt);
    expect(restored.updatedAt, event.updatedAt);
  });

  test('invalid persisted weekday code throws instead of defaulting', () {
    expect(
      () => MedicationSchedule.fromDbRow(<String, Object?>{
        'id': 'schedule-1',
        'name': 'Amlodipine',
        'dosage': '1 tablet',
        'purpose': 'Blood pressure',
        'dose_times': '08:00',
        'active_days': 'noday',
        'alarm_escalation_enabled': 1,
        'is_active': 1,
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
    );
  });

  test('invalid persisted escalation level throws instead of defaulting', () {
    expect(
      () => MedicationDoseEvent.fromDbRow(<String, Object?>{
        'id': 'dose-1',
        'schedule_id': 'schedule-1',
        'scheduled_at': 1,
        'status': 'pending',
        'escalation_level': 4,
        'reminder_sent_at': null,
        'acted_at': null,
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
    );
  });
}
