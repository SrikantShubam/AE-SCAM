import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_db.dart';
import '../../medication/models/medication_dose_event.dart';
import '../payment_protection_bridge.dart';

class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.accessibilityEnabled,
    required this.notificationListenerEnabled,
    required this.firebaseConnectivityState,
    required this.pairId,
    required this.emergencyDisabled,
    required this.lastFcmToken,
    required this.accessibilityEvents,
    required this.notificationEvents,
    required this.medicationEvents,
    required this.safeBrowsingRefreshTimestamps,
    required this.safeBrowsingHitCount,
  });

  final bool accessibilityEnabled;
  final bool notificationListenerEnabled;
  final String firebaseConnectivityState;
  final String? pairId;
  final bool emergencyDisabled;
  final String? lastFcmToken;
  final List<Map<String, dynamic>> accessibilityEvents;
  final List<Map<String, dynamic>> notificationEvents;
  final List<MedicationDoseEvent> medicationEvents;
  final List<int> safeBrowsingRefreshTimestamps;
  final int safeBrowsingHitCount;
}

class DiagnosticsService {
  DiagnosticsService({LocalDb? localDb}) : _localDb = localDb ?? LocalDb.instance;

  static const String _notificationEventsKey = 'diagnostics_notification_events_v1';
  final LocalDb _localDb;

  static Future<void> appendNotificationEvent({
    required String? sender,
    required String messageBody,
    required String matchResult,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _decodeJsonList(
      prefs.getString(_notificationEventsKey),
    );
    final entry = <String, dynamic>{
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
      'sender': (sender ?? '').trim(),
      'preview': messageBody.trim().replaceAll('\n', ' ').substring(
        0,
        messageBody.trim().length < 80 ? messageBody.trim().length : 80,
      ),
      'matchResult': matchResult,
    };
    final updated = <Map<String, dynamic>>[entry, ...existing].take(20).toList();
    await prefs.setString(_notificationEventsKey, jsonEncode(updated));
  }

  Future<DiagnosticsSnapshot> load() async {
    final native = await PaymentProtectionBridge.loadDiagnosticsSnapshot();
    final prefs = await SharedPreferences.getInstance();
    final medicationRows = await _localDb.listRecentMedicationDoseEventRows(limit: 20);
    final medicationEvents = medicationRows
        .map(MedicationDoseEvent.fromDbRow)
        .toList(growable: false);
    final firebaseConnectivityState = await _readFirebaseConnectivity();
    final pairId = _asTrimmed(native['pairId']) ?? prefs.getString('pair_id');
    final emergencyDisabled = await _readEmergencyDisabled(pairId);
    final lastFcmToken = await _readFcmToken();

    return DiagnosticsSnapshot(
      accessibilityEnabled: native['accessibilityEnabled'] as bool? ?? false,
      notificationListenerEnabled:
          native['notificationListenerEnabled'] as bool? ?? false,
      firebaseConnectivityState: firebaseConnectivityState,
      pairId: pairId,
      emergencyDisabled: emergencyDisabled,
      lastFcmToken: lastFcmToken ?? _asTrimmed(native['lastFcmToken']),
      accessibilityEvents: _readNativeEvents(native['accessibilityEvents']),
      notificationEvents: _decodeJsonList(
        prefs.getString(_notificationEventsKey),
      ),
      medicationEvents: medicationEvents,
      safeBrowsingRefreshTimestamps: _readIntList(native['safeBrowsingRefreshesMs']),
      safeBrowsingHitCount: native['safeBrowsingHitCount'] as int? ?? 0,
    );
  }

  static List<Map<String, dynamic>> _decodeJsonList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readNativeEvents(Object? raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  List<int> _readIntList(Object? raw) {
    if (raw is! List) {
      return const <int>[];
    }
    return raw
        .map((value) {
          if (value is int) {
            return value;
          }
          if (value is num) {
            return value.toInt();
          }
          return int.tryParse('$value');
        })
        .whereType<int>()
        .toList(growable: false);
  }

  String? _asTrimmed(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  Future<String> _readFirebaseConnectivity() async {
    try {
      await FirebaseFirestore.instance
          .collection('_guardian')
          .doc('connectivity_probe')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
      return 'online';
    } catch (_) {
      return 'offline_or_unknown';
    }
  }

  Future<bool> _readEmergencyDisabled(String? pairId) async {
    if (pairId == null || pairId.isEmpty) {
      return false;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pairs')
          .doc(pairId)
          .get()
          .timeout(const Duration(seconds: 3));
      final settings = doc.data()?['settings'];
      if (settings is Map<String, dynamic>) {
        return settings['emergency_disabled'] as bool? ?? false;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> _readFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 3));
      final normalized = token?.trim();
      if (normalized == null || normalized.isEmpty) {
        return null;
      }
      return normalized;
    } catch (_) {
      return null;
    }
  }
}
