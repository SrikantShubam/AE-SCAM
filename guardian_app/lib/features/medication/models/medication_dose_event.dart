enum MedicationDoseStatus {
  pending('pending'),
  taken('taken'),
  skipped('skipped'),
  alarmActive('alarm_active');

  const MedicationDoseStatus(this.code);

  final String code;

  static MedicationDoseStatus fromCode(String rawCode) {
    return MedicationDoseStatus.values.firstWhere(
      (value) => value.code == rawCode,
      orElse: () =>
          throw FormatException('Invalid medication dose status: $rawCode'),
    );
  }
}

enum MedicationEscalationLevel {
  none(0),
  level1(1),
  level3(3);

  const MedicationEscalationLevel(this.value);

  final int value;

  static MedicationEscalationLevel fromValue(int rawValue) {
    return MedicationEscalationLevel.values.firstWhere(
      (value) => value.value == rawValue,
      orElse: () => throw FormatException(
        'Invalid medication escalation level: $rawValue',
      ),
    );
  }
}

class MedicationDoseEvent {
  const MedicationDoseEvent({
    required this.id,
    required this.scheduleId,
    required this.scheduledAt,
    required this.status,
    required this.escalationLevel,
    required this.reminderSentAt,
    required this.actedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String scheduleId;
  final DateTime scheduledAt;
  final MedicationDoseStatus status;
  final MedicationEscalationLevel escalationLevel;
  final DateTime? reminderSentAt;
  final DateTime? actedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicationDoseEvent copyWith({
    String? id,
    String? scheduleId,
    DateTime? scheduledAt,
    MedicationDoseStatus? status,
    MedicationEscalationLevel? escalationLevel,
    DateTime? reminderSentAt,
    DateTime? actedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationDoseEvent(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      actedAt: actedAt ?? this.actedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDbRow() {
    return <String, Object?>{
      'id': id,
      'schedule_id': scheduleId,
      'scheduled_at': scheduledAt.toUtc().millisecondsSinceEpoch,
      'status': status.code,
      'escalation_level': escalationLevel.value,
      'reminder_sent_at': reminderSentAt?.toUtc().millisecondsSinceEpoch,
      'acted_at': actedAt?.toUtc().millisecondsSinceEpoch,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  factory MedicationDoseEvent.fromDbRow(Map<String, Object?> row) {
    return MedicationDoseEvent(
      id: row['id']! as String,
      scheduleId: row['schedule_id']! as String,
      scheduledAt: _requiredEpoch(row['scheduled_at']),
      status: MedicationDoseStatus.fromCode(row['status']! as String),
      escalationLevel: MedicationEscalationLevel.fromValue(
        (row['escalation_level'] as num).toInt(),
      ),
      reminderSentAt: _optionalEpoch(row['reminder_sent_at']),
      actedAt: _optionalEpoch(row['acted_at']),
      createdAt: _requiredEpoch(row['created_at']),
      updatedAt: _requiredEpoch(row['updated_at']),
    );
  }

  static DateTime _requiredEpoch(Object? value) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value as num).toInt(),
      isUtc: true,
    );
  }

  static DateTime? _optionalEpoch(Object? value) {
    final epoch = (value as num?)?.toInt();
    if (epoch == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
  }
}
