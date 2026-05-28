import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication_dose_event.dart';
import 'medication_alarm_platform_bridge.dart';
import 'medication_repository.dart';

class MedicationAlarmAckSyncService {
  MedicationAlarmAckSyncService({
    required MedicationAlarmPlatformBridge bridge,
    required MedicationRepository repository,
    SharedPreferences? prefs,
    FirebaseFirestore? firestore,
    Future<List<Map<String, dynamic>>> Function()? pendingAcknowledgementsProvider,
  }) : _bridge = bridge,
       _repository = repository,
       _prefs = prefs,
       _firestore = firestore,
       _pendingAcknowledgementsProvider = pendingAcknowledgementsProvider;

  final MedicationAlarmPlatformBridge _bridge;
  final MedicationRepository _repository;
  final SharedPreferences? _prefs;
  final FirebaseFirestore? _firestore;
  final Future<List<Map<String, dynamic>>> Function()?
  _pendingAcknowledgementsProvider;

  Future<void> syncPendingAcknowledgements() async {
    final pending = await (_pendingAcknowledgementsProvider?.call() ??
        _bridge.consumePendingAlarmAcknowledgements());
    if (pending.isEmpty) {
      return;
    }
    final prefs = await (_prefs == null
        ? SharedPreferences.getInstance()
        : Future<SharedPreferences>.value(_prefs!));
    final pairId = prefs.getString('pair_id')?.trim();

    for (final item in pending) {
      final eventId = (item['event_id'] as String? ?? '').trim();
      final statusRaw = (item['status'] as String? ?? '').trim();
      if (eventId.isEmpty || statusRaw.isEmpty) {
        continue;
      }

      final status = _parseStatus(statusRaw);
      final skipReasonRaw = (item['skip_reason'] as String? ?? '').trim();
      final skipReason = skipReasonRaw.isEmpty ? null : skipReasonRaw;
      final acknowledgedAtMs = _readInt(item['acknowledged_at_ms']);
      final acknowledgedAt = acknowledgedAtMs == null
          ? DateTime.now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(acknowledgedAtMs, isUtc: true);

      final updated = await _repository.updateDoseEvent(
        eventId: eventId,
        status: status,
        skipReason: skipReason,
        actedAt: acknowledgedAt,
      );
      if (pairId == null || pairId.isEmpty) {
        continue;
      }
      await _syncToFirestore(
        pairId: pairId,
        updatedEvent: updated,
        medicationNameHint: (item['medication_name'] as String?)?.trim(),
      );
    }
  }

  Future<void> _syncToFirestore({
    required String pairId,
    required MedicationDoseEvent updatedEvent,
    required String? medicationNameHint,
  }) async {
    final firestore = _activeFirestore;
    if (firestore == null) {
      return;
    }
    final schedule = await _repository.getScheduleById(updatedEvent.scheduleId);
    final medicationName = medicationNameHint != null && medicationNameHint.isNotEmpty
        ? medicationNameHint
        : (schedule?.name ?? '');
    await firestore
        .collection('pairs')
        .doc(pairId)
        .collection('medication_events')
        .doc(updatedEvent.id)
        .set(<String, Object?>{
          'schedule_id': updatedEvent.scheduleId,
          'medication_name': medicationName,
          'scheduled_at': Timestamp.fromDate(updatedEvent.scheduledAt.toUtc()),
          'status': updatedEvent.status.code,
          'acknowledged_at': updatedEvent.actedAt == null
              ? null
              : Timestamp.fromDate(updatedEvent.actedAt!.toUtc()),
          'acknowledged_via': 'alarm',
          if (updatedEvent.skipReason != null &&
              updatedEvent.skipReason!.trim().isNotEmpty)
            'skip_reason': updatedEvent.skipReason!.trim(),
        }, SetOptions(merge: true));
  }

  FirebaseFirestore? get _activeFirestore {
    if (_firestore != null) {
      return _firestore;
    }
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance;
  }

  MedicationDoseStatus _parseStatus(String raw) {
    switch (raw) {
      case 'taken':
        return MedicationDoseStatus.taken;
      case 'skipped':
        return MedicationDoseStatus.skipped;
      case 'alarm_active':
        return MedicationDoseStatus.alarmActive;
      case 'pending':
      default:
        return MedicationDoseStatus.pending;
    }
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
