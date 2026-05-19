import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/medication/models/medication_dose_event.dart';
import 'package:guardian/features/medication/models/medication_schedule.dart';

void main() {
  test('medication schedule supports db round-trip serialization', () {
    final now = DateTime.utc(2026, 4, 10, 8, 30);
    final schedule = MedicationSchedule(
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
      stopDate: DateTime.utc(2026, 4, 30),
      note: 'Give with food',
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
    expect(restored.stopDate, schedule.stopDate);
    expect(restored.note, schedule.note);
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
      skipReason: null,
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
        'stop_date': null,
        'note': null,
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
        'skip_reason': null,
        'reminder_sent_at': null,
        'acted_at': null,
        'created_at': 1,
        'updated_at': 1,
      }),
      throwsFormatException,
    );
  });

  test('copyWith can clear nullable stopDate and note fields', () {
    final original = MedicationSchedule(
      id: 'schedule-1',
      name: 'Amlodipine',
      dosage: '1 tablet',
      purpose: 'Blood pressure',
      doseTimes: <String>['08:00', '20:00'],
      activeDays: <MedicationWeekday>{
        MedicationWeekday.mon,
        MedicationWeekday.wed,
        MedicationWeekday.fri,
      },
      alarmEscalationEnabled: true,
      stopDate: DateTime.utc(2026, 4, 30),
      note: 'Give with food',
      createdAt: DateTime.utc(2026, 4, 10, 8, 30),
      updatedAt: DateTime.utc(2026, 4, 10, 8, 45),
    );

    final updated = original.copyWith(stopDate: null, note: null);

    expect(updated.stopDate, isNull);
    expect(updated.note, isNull);

    expect(updated.id, original.id);
    expect(updated.name, original.name);
    expect(updated.dosage, original.dosage);
    expect(updated.purpose, original.purpose);
    expect(updated.doseTimes, original.doseTimes);
    expect(updated.activeDays, original.activeDays);
    expect(
      updated.alarmEscalationEnabled,
      original.alarmEscalationEnabled,
    );
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt, original.updatedAt);
  });

  test('copyWith preserves nullable stopDate and note when omitted', () {
    final original = MedicationSchedule(
      id: 'schedule-1',
      name: 'Amlodipine',
      dosage: '1 tablet',
      purpose: 'Blood pressure',
      doseTimes: <String>['08:00'],
      activeDays: <MedicationWeekday>{MedicationWeekday.mon},
      alarmEscalationEnabled: true,
      stopDate: DateTime.utc(2026, 4, 30),
      note: 'Give with food',
    );

    final updated = original.copyWith(name: 'Amlodipine updated');

    expect(updated.name, 'Amlodipine updated');
    expect(updated.stopDate, original.stopDate);
    expect(updated.note, original.note);
  });
}
