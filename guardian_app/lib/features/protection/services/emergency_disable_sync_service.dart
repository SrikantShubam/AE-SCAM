import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyDisableSyncService {
  EmergencyDisableSyncService({
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
  }) : _firestore = firestore,
       _prefs = prefs;

  static const String _prefsKey = 'emergency_disabled';
  final FirebaseFirestore? _firestore;
  final SharedPreferences? _prefs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<RemoteMessage>? _foregroundFcmSubscription;

  Future<void> start() async {
    final prefs = await _getPrefs();
    final role = prefs.getString('user_role') ?? 'parent';
    if (role != 'parent') {
      return;
    }
    final pairId = prefs.getString('pair_id');
    if (pairId == null || pairId.isEmpty) {
      return;
    }
    final firestore = _activeFirestore;
    if (firestore == null) {
      return;
    }
    await _subscription?.cancel();
    _subscription = firestore.collection('pairs').doc(pairId).snapshots().listen((
      snapshot,
    ) async {
      final settings = snapshot.data()?['settings'];
      final disabled = settings is Map<String, dynamic>
          ? settings['emergency_disabled'] as bool? ?? false
          : false;
      await prefs.setBool(_prefsKey, disabled);
    });
    await _syncParentFcmToken(
      prefs: prefs,
      firestore: firestore,
      pairId: pairId,
      role: role,
    );
    await _foregroundFcmSubscription?.cancel();
    _foregroundFcmSubscription = FirebaseMessaging.onMessage.listen((message) {
      applyFcmDataPayload(message.data);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _foregroundFcmSubscription?.cancel();
    _foregroundFcmSubscription = null;
  }

  Future<bool> isEmergencyDisabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<bool> toggleFromCaregiver() async {
    final prefs = await _getPrefs();
    final pairId = prefs.getString('pair_id');
    if (pairId == null || pairId.isEmpty) {
      throw StateError('Missing pair_id.');
    }
    final firestore = _activeFirestore;
    if (firestore == null) {
      throw StateError('Firestore unavailable.');
    }
    final next = !(prefs.getBool(_prefsKey) ?? false);
    await firestore.collection('pairs').doc(pairId).set(<String, dynamic>{
      'settings': <String, dynamic>{'emergency_disabled': next},
    }, SetOptions(merge: true));
    await prefs.setBool(_prefsKey, next);
    return next;
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
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

  Future<void> _syncParentFcmToken({
    required SharedPreferences prefs,
    required FirebaseFirestore firestore,
    required String pairId,
    required String role,
  }) async {
    if (role != 'parent') {
      return;
    }
    final deviceId = prefs.getString('guardian_device_id');
    if (deviceId == null || deviceId.isEmpty) {
      return;
    }
    String? token;
    try {
      token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } catch (_) {
      token = null;
    }
    final normalizedToken = token?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      return;
    }
    await prefs.setString('last_fcm_token', normalizedToken);
    await firestore
        .collection('pairs')
        .doc(pairId)
        .collection('devices')
        .doc(deviceId)
        .set(<String, dynamic>{
          'role': 'parent',
          'fcm_token': normalizedToken,
          'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
  }

  static Future<void> applyFcmDataPayload(Map<String, dynamic> data) async {
    final eventType = data['event_type']?.toString().trim();
    if (eventType != 'emergency_disable_changed') {
      return;
    }
    final rawValue = data['emergency_disabled']?.toString().trim().toLowerCase();
    if (rawValue != 'true' && rawValue != 'false') {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, rawValue == 'true');
  }
}
