enum MedicationWeekday {
  mon('mon'),
  tue('tue'),
  wed('wed'),
  thu('thu'),
  fri('fri'),
  sat('sat'),
  sun('sun');

  const MedicationWeekday(this.code);

  final String code;

  static MedicationWeekday fromCode(String rawCode) {
    return MedicationWeekday.values.firstWhere(
      (value) => value.code == rawCode,
      orElse: () =>
          throw FormatException('Invalid medication weekday code: $rawCode'),
    );
  }
}

class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.name,
    required this.dosage,
    required this.purpose,
    required this.doseTimes,
    required this.activeDays,
    required this.alarmEscalationEnabled,
    this.stopDate,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final String? purpose;
  final List<String> doseTimes;
  final Set<MedicationWeekday> activeDays;
  final bool alarmEscalationEnabled;
  final DateTime? stopDate;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicationSchedule copyWith({
    String? id,
    String? name,
    String? dosage,
    String? purpose,
    List<String>? doseTimes,
    Set<MedicationWeekday>? activeDays,
    bool? alarmEscalationEnabled,
    DateTime? stopDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicationSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      purpose: purpose ?? this.purpose,
      doseTimes: doseTimes ?? this.doseTimes,
      activeDays: activeDays ?? this.activeDays,
      alarmEscalationEnabled:
          alarmEscalationEnabled ?? this.alarmEscalationEnabled,
      stopDate: stopDate ?? this.stopDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDbRow({
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return <String, Object?>{
      'id': id,
      'name': name,
      'dosage': dosage,
      'purpose': purpose,
      'dose_times': doseTimes.join(','),
      'active_days': activeDays.map((day) => day.code).join(','),
      'alarm_escalation_enabled': alarmEscalationEnabled ? 1 : 0,
      'stop_date': stopDate?.toUtc().millisecondsSinceEpoch,
      'note': note,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
    };
  }

  factory MedicationSchedule.fromDbRow(Map<String, Object?> row) {
    final doseTimes = _decodeCsv(row['dose_times'] as String?);
    final activeDayCodes = _decodeCsv(row['active_days'] as String?);
    if (doseTimes.isEmpty) {
      throw FormatException('Medication schedule is missing dose times.');
    }
    if (activeDayCodes.isEmpty) {
      throw FormatException('Medication schedule is missing active days.');
    }

    return MedicationSchedule(
      id: row['id']! as String,
      name: row['name']! as String,
      dosage: row['dosage']! as String,
      purpose: row['purpose'] as String?,
      doseTimes: doseTimes,
      activeDays: activeDayCodes.map(MedicationWeekday.fromCode).toSet(),
      alarmEscalationEnabled:
          ((row['alarm_escalation_enabled'] as num?)?.toInt() ?? 0) == 1,
      stopDate: _fromEpoch(row['stop_date']),
      note: row['note'] as String?,
      createdAt: _fromEpoch(row['created_at']),
      updatedAt: _fromEpoch(row['updated_at']),
    );
  }

  static List<String> _decodeCsv(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>[];
    }
    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _fromEpoch(Object? value) {
    final epoch = (value as num?)?.toInt();
    if (epoch == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
  }
}
