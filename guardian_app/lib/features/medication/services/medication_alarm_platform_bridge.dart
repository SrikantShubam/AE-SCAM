import 'package:flutter/services.dart';
import 'dart:convert';

import '../models/medication_reminder_plan.dart';

class MedicationAlarmPlatformBridge {
  MedicationAlarmPlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.guardian/medication_alarm';
  final MethodChannel _channel;

  Future<bool> isExactAlarmPermissionGranted() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'isExactAlarmPermissionGranted',
      );
      return granted ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on PlatformException {
      // Best effort: no-op when platform settings cannot be opened.
    } on MissingPluginException {
      // Best effort: no-op when no Android implementation exists.
    }
  }

  Future<void> scheduleTrigger({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {
    await _channel.invokeMethod<void>('scheduleMedicationTrigger', <String, Object>{
      'occurrenceId': occurrence.occurrenceId,
      'triggerId': trigger.triggerId,
      'stage': trigger.stage.name,
      'triggerAtMs': trigger.triggerAt.millisecondsSinceEpoch,
      'medicationName': occurrence.medicationName,
      'dosage': occurrence.dosage,
      'note': occurrence.note ?? '',
    });
  }

  Future<void> cancelOccurrence(String occurrenceId) async {
    await _channel.invokeMethod<void>('cancelMedicationOccurrence', <String, Object>{
      'occurrenceId': occurrenceId,
    });
  }

  Future<List<Map<String, dynamic>>> consumePendingAlarmAcknowledgements() async {
    final payloads = await _channel.invokeMethod<List<dynamic>>(
      'consumePendingAlarmAcknowledgements',
    );
    if (payloads == null || payloads.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return payloads
        .map((raw) => _decodeAckPayload(raw?.toString()))
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Map<String, dynamic>? _decodeAckPayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }
}
