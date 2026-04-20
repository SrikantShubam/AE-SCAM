import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/local_db.dart';
import '../../protection/services/url_reputation_checker.dart';
import '../models/scam_candidate.dart';
import 'scam_suspicion_heuristic.dart';

class ScamCandidateQueueResult {
  const ScamCandidateQueueResult._({
    required this.triggered,
    required this.queued,
    required this.confirmedThreat,
  });

  final bool triggered;
  final bool queued;
  final bool confirmedThreat;

  factory ScamCandidateQueueResult.notTriggered() {
    return const ScamCandidateQueueResult._(
      triggered: false,
      queued: false,
      confirmedThreat: false,
    );
  }

  factory ScamCandidateQueueResult.queued() {
    return const ScamCandidateQueueResult._(
      triggered: true,
      queued: true,
      confirmedThreat: false,
    );
  }

  factory ScamCandidateQueueResult.confirmedThreat() {
    return const ScamCandidateQueueResult._(
      triggered: true,
      queued: false,
      confirmedThreat: true,
    );
  }
}

class ScamCandidateRepository {
  ScamCandidateRepository({
    required LocalDb localDb,
    UrlReputationChecker? urlReputationChecker,
    FirebaseFirestore? firestore,
    SharedPreferences? prefs,
  }) : _localDb = localDb,
       _urlReputationChecker =
           urlReputationChecker ?? const UrlReputationChecker(),
       _firestore = firestore,
       _prefs = prefs;

  static const String _pendingType = 'scam_candidate';
  static const String _shareScamTextWithCaregiverKey =
      'share_scam_text_with_caregiver';

  final LocalDb _localDb;
  final UrlReputationChecker _urlReputationChecker;
  final FirebaseFirestore? _firestore;
  final SharedPreferences? _prefs;

  Future<ScamCandidateQueueResult> evaluateAndQueueIfSuspicious({
    required String text,
    required String? sender,
    required String source,
    bool senderInContacts = false,
  }) async {
    final heuristic = ScamSuspicionHeuristic.evaluate(
      text: text,
      senderInContacts: senderInContacts,
    );
    if (!heuristic.triggered) {
      return ScamCandidateQueueResult.notTriggered();
    }

    final urlVerdicts = <String>[];
    var hasConfirmedThreat = false;
    for (final url in heuristic.detectedUrls) {
      final verdict = await _urlReputationChecker.check(url);
      urlVerdicts.add('$url:${verdict.name}');
      if (verdict == ThreatVerdict.phishing ||
          verdict == ThreatVerdict.malware) {
        hasConfirmedThreat = true;
      }
    }

    if (hasConfirmedThreat) {
      return ScamCandidateQueueResult.confirmedThreat();
    }

    final candidate = ScamCandidate(
      id: _generateCandidateId(),
      source: source,
      textHash: _sha256(text),
      text: text,
      sender: sender,
      signalsMatched: heuristic.matchedSignals,
      urlVerdicts: urlVerdicts,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      status: 'pending_review',
    );

    final includeSensitiveText = await _shareSensitiveTextEnabled();
    await _enqueueLocalCandidate(
      candidate,
      includeSensitiveText: includeSensitiveText,
    );

    final pushedRemote = await _pushRemoteCandidate(
      candidate,
      includeSensitiveText: includeSensitiveText,
    );
    if (pushedRemote) {
      await _markCandidateSynced(candidate.id);
    }
    return ScamCandidateQueueResult.queued();
  }

  Future<void> _enqueueLocalCandidate(
    ScamCandidate candidate, {
    required bool includeSensitiveText,
  }) async {
    await _localDb.enqueuePendingEvent(
      id: candidate.id,
      type: _pendingType,
      payload: jsonEncode(
        candidate.toRemoteMap(includeSensitiveText: includeSensitiveText),
      ),
    );
  }

  Future<void> _markCandidateSynced(String id) async {
    final db = await _localDb.database;
    await db.update(
      'pending_events',
      <String, Object?>{'synced': 1},
      where: 'id = ? AND type = ?',
      whereArgs: <Object?>[id, _pendingType],
    );
  }

  Future<bool> _pushRemoteCandidate(
    ScamCandidate candidate, {
    required bool includeSensitiveText,
  }) async {
    if (Firebase.apps.isEmpty) {
      return false;
    }

    final prefs = await _getPrefs();
    final userRole = prefs.getString('user_role') ?? 'parent';
    if (userRole != 'parent') {
      return false;
    }

    final pairId =
        prefs.getString('pair_id') ??
        prefs.getString('guardian_family_id') ??
        prefs.getString('pairing_code');
    if (pairId == null || pairId.isEmpty) {
      return false;
    }

    final firestore = _firestore ?? FirebaseFirestore.instance;
    try {
      await firestore
          .collection('pairs')
          .doc(pairId)
          .collection('scam_candidates')
          .doc(candidate.id)
          .set(
            candidate.toRemoteMap(includeSensitiveText: includeSensitiveText),
            SetOptions(merge: true),
          );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _shareSensitiveTextEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_shareScamTextWithCaregiverKey) ?? false;
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  String _generateCandidateId() {
    return 'scam-candidate-${DateTime.now().microsecondsSinceEpoch}';
  }

  String _sha256(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }
}
