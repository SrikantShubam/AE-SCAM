import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PairingService {
  PairingService({
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
    Random? random,
  }) : _firestore = firestore,
       _prefs = prefs,
       _random = random ?? Random.secure();

  static const allowedAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const pairingCodeLength = 6;
  static const pairingDocCollection = 'pairing';
  static const pairingExpiry = Duration(hours: 24);

  static const pairIdKey = 'pair_id';
  static const familyIdKey = 'guardian_family_id';
  static const pairingCodeKey = 'pairing_code';
  static const pairingPendingCodeKey = 'pairing_pending_code';
  static const pairingPendingReasonKey = 'pairing_pending_reason';
  static const pairingStatusKey = 'pairing_status';
  static const deviceIdKey = 'guardian_device_id';
  static const caregiverCodeCreatedAtKey = 'caregiver_pairing_created_at_ms';
  static const caregiverCodeExpiresAtKey = 'caregiver_pairing_expires_at_ms';

  final FirebaseFirestore? _firestore;
  final SharedPreferences? _prefs;
  final Random _random;

  static String generatePairingCode({Random? random}) {
    final source = random ?? Random.secure();
    return List<String>.generate(pairingCodeLength, (_) {
      return allowedAlphabet[source.nextInt(allowedAlphabet.length)];
    }).join();
  }

  Future<PairingDraftResult> createCaregiverCode() async {
    final prefs = await _getPrefs();
    final firestore = _activeFirestore;
    if (firestore == null) {
      return PairingDraftResult.failure(
        PairingFailureReason.offline,
        'Guardian could not reach pairing yet. Connect to the internet and try again.',
      );
    }

    final caregiverDeviceId = await _ensureDeviceId(prefs);
    final pairId = prefs.getString(pairIdKey) ?? _generatePairId();
    final now = DateTime.now();
    final expiresAt = now.add(pairingExpiry);

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generatePairingCode(random: _random);
      final doc = firestore.collection(pairingDocCollection).doc(code);

      try {
        final snapshot = await doc.get();
        if (snapshot.exists) {
          final data = snapshot.data() ?? <String, dynamic>{};
          final expiresAtMs = _readInt(data['expires_at_ms']);
          final claimedAtMs = _readInt(data['claimed_at_ms']);
          final isExpired =
              expiresAtMs != null &&
              DateTime.fromMillisecondsSinceEpoch(expiresAtMs).isBefore(now);
          final isClaimed = claimedAtMs != null;
          if (!isExpired && !isClaimed) {
            continue;
          }
        }

        await doc.set(<String, dynamic>{
          'code': code,
          'pair_id': pairId,
          'caregiver_device_id': caregiverDeviceId,
          'created_at_ms': now.millisecondsSinceEpoch,
          'expires_at_ms': expiresAt.millisecondsSinceEpoch,
          'claimed_at_ms': null,
          'claimed_by_device_id': null,
          'status': 'pending',
        });

        await prefs.setString(pairIdKey, pairId);
        await prefs.setString(familyIdKey, pairId);
        await prefs.setString(pairingCodeKey, code);
        await prefs.setInt(caregiverCodeCreatedAtKey, now.millisecondsSinceEpoch);
        await prefs.setInt(caregiverCodeExpiresAtKey, expiresAt.millisecondsSinceEpoch);
        await prefs.remove(pairingPendingCodeKey);
        await prefs.remove(pairingPendingReasonKey);
        await prefs.setString(pairingStatusKey, 'ready');

        return PairingDraftResult.success(
          code: code,
          pairId: pairId,
          expiresAt: expiresAt,
        );
      } catch (_) {
        return PairingDraftResult.failure(
          PairingFailureReason.offline,
          'Guardian could not save the pairing code yet. Try again in a moment.',
        );
      }
    }

    return PairingDraftResult.failure(
      PairingFailureReason.offline,
      'Guardian could not create a clear pairing code right now. Try again.',
    );
  }

  Future<PairingClaimResult> claimParentCode(String rawCode) async {
    final code = sanitizeCode(rawCode);
    if (code.length != pairingCodeLength) {
      return PairingClaimResult.failure(
        PairingFailureReason.invalidCode,
        'Enter the 6-character code exactly as your caregiver shared it.',
      );
    }

    final prefs = await _getPrefs();
    final firestore = _activeFirestore;
    if (firestore == null) {
      await _storePendingClaim(
        prefs,
        code: code,
        reason: PairingFailureReason.offline.name,
      );
      return PairingClaimResult.failure(
        PairingFailureReason.offline,
        'Guardian could not reach pairing yet. We saved the code so you can retry when online.',
      );
    }

    final parentDeviceId = await _ensureDeviceId(prefs);
    final doc = firestore.collection(pairingDocCollection).doc(code);

    try {
      final result = await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(doc);
        if (!snapshot.exists) {
          return PairingClaimResult.failure(
            PairingFailureReason.invalidCode,
            'That code does not look right. Check the letters and numbers and try again.',
          );
        }

        final data = snapshot.data() ?? <String, dynamic>{};
        final expiresAtMs = _readInt(data['expires_at_ms']);
        final claimedAtMs = _readInt(data['claimed_at_ms']);
        final pairId = data['pair_id'] as String?;

        if (pairId == null || pairId.isEmpty) {
          return PairingClaimResult.failure(
            PairingFailureReason.invalidCode,
            'That pairing code is missing details. Ask the caregiver to generate a new one.',
          );
        }

        if (expiresAtMs != null &&
            DateTime.fromMillisecondsSinceEpoch(expiresAtMs).isBefore(DateTime.now())) {
          return PairingClaimResult.failure(
            PairingFailureReason.expired,
            'That code has expired. Ask the caregiver to share a fresh code.',
          );
        }

        if (claimedAtMs != null) {
          return PairingClaimResult.failure(
            PairingFailureReason.alreadyClaimed,
            'That code was already used. Ask the caregiver for a new one.',
          );
        }

        transaction.update(doc, <String, dynamic>{
          'claimed_at_ms': FieldValue.serverTimestamp(),
          'claimed_by_device_id': parentDeviceId,
          'status': 'claimed',
        });

        return PairingClaimResult.success(pairId: pairId, code: code);
      });

      if (result.isSuccess) {
        await _persistLinkedPair(prefs, pairId: result.pairId!, code: code);
        await prefs.remove(pairingPendingCodeKey);
        await prefs.remove(pairingPendingReasonKey);
      } else if (result.reason == PairingFailureReason.offline) {
        await _storePendingClaim(
          prefs,
          code: code,
          reason: result.reason!.name,
        );
      }

      return result;
    } catch (_) {
      await _storePendingClaim(
        prefs,
        code: code,
        reason: PairingFailureReason.offline.name,
      );
      return PairingClaimResult.failure(
        PairingFailureReason.offline,
        'Guardian could not confirm that code yet. We saved it so you can retry.',
      );
    }
  }

  Future<String?> pendingCode() async {
    final prefs = await _getPrefs();
    return prefs.getString(pairingPendingCodeKey);
  }

  String sanitizeCode(String rawCode) {
    return rawCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Future<void> _persistLinkedPair(
    SharedPreferences prefs, {
    required String pairId,
    required String code,
  }) async {
    await prefs.setString(pairIdKey, pairId);
    await prefs.setString(familyIdKey, pairId);
    await prefs.setString(pairingCodeKey, code);
    await prefs.setString(pairingStatusKey, 'linked');
  }

  Future<void> _storePendingClaim(
    SharedPreferences prefs, {
    required String code,
    required String reason,
  }) async {
    await prefs.setString(pairingPendingCodeKey, code);
    await prefs.setString(pairingPendingReasonKey, reason);
    await prefs.setString(pairingStatusKey, 'pending_retry');
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  FirebaseFirestore? get _activeFirestore {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return _firestore ?? FirebaseFirestore.instance;
  }

  Future<String> _ensureDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final deviceId = 'device-${DateTime.now().microsecondsSinceEpoch}';
    await prefs.setString(deviceIdKey, deviceId);
    return deviceId;
  }

  String _generatePairId() {
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final prefix = List<String>.generate(4, (_) {
      return allowedAlphabet[_random.nextInt(allowedAlphabet.length)];
    }).join();
    return 'pair-$prefix$suffix';
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    return null;
  }
}

enum PairingFailureReason {
  invalidCode,
  expired,
  alreadyClaimed,
  offline,
}

class PairingDraftResult {
  const PairingDraftResult._({
    required this.isSuccess,
    this.code,
    this.pairId,
    this.expiresAt,
    this.reason,
    this.message,
  });

  final bool isSuccess;
  final String? code;
  final String? pairId;
  final DateTime? expiresAt;
  final PairingFailureReason? reason;
  final String? message;

  factory PairingDraftResult.success({
    required String code,
    required String pairId,
    required DateTime expiresAt,
  }) {
    return PairingDraftResult._(
      isSuccess: true,
      code: code,
      pairId: pairId,
      expiresAt: expiresAt,
    );
  }

  factory PairingDraftResult.failure(
    PairingFailureReason reason,
    String message,
  ) {
    return PairingDraftResult._(
      isSuccess: false,
      reason: reason,
      message: message,
    );
  }
}

class PairingClaimResult {
  const PairingClaimResult._({
    required this.isSuccess,
    this.pairId,
    this.code,
    this.reason,
    this.message,
  });

  final bool isSuccess;
  final String? pairId;
  final String? code;
  final PairingFailureReason? reason;
  final String? message;

  factory PairingClaimResult.success({
    required String pairId,
    required String code,
  }) {
    return PairingClaimResult._(isSuccess: true, pairId: pairId, code: code);
  }

  factory PairingClaimResult.failure(
    PairingFailureReason reason,
    String message,
  ) {
    return PairingClaimResult._(
      isSuccess: false,
      reason: reason,
      message: message,
    );
  }
}
