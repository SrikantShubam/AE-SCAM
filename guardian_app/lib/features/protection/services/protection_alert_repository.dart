import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/local_db.dart';
import '../models/protection_alert.dart';

abstract class ProtectionAlertRemoteSink {
  /// Pushes the alert to a remote backend.
  ///
  /// Returns `true` if a remote write was attempted with usable context,
  /// `false` if the sink was effectively a no-op (e.g. missing identity
  /// or Firebase not initialized).
  Future<bool> pushAlert(GuardianProtectionAlert alert);
}

class FirestoreProtectionAlertRemoteSink implements ProtectionAlertRemoteSink {
  FirestoreProtectionAlertRemoteSink({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<_RemoteContext?> _resolveContext() async {
    // If Firebase isn't initialized, bail out early.
    if (Firebase.apps.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role') ?? 'parent';

    if (userRole != 'parent') {
      // Only parent devices should emit protection alerts.
      return null;
    }

    final familyId =
        prefs.getString('pair_id') ??
        prefs.getString('guardian_family_id') ??
        prefs.getString('pairing_code');

    if (familyId == null || familyId.isEmpty) {
      // No usable family identity yet; keep local-only.
      return null;
    }

    return _RemoteContext(familyId: familyId, deviceRole: userRole);
  }

  @override
  Future<bool> pushAlert(GuardianProtectionAlert alert) async {
    final ctx = await _resolveContext();
    if (ctx == null) {
      return false;
    }

    final firestore = _firestore ?? FirebaseFirestore.instance;

    try {
      await firestore
          .collection('guardian_families')
          .doc(ctx.familyId)
          .collection('protection_alerts')
          .doc(alert.id)
          .set(
            alert.toRemoteMap(
              familyId: ctx.familyId,
              deviceRole: ctx.deviceRole,
            ),
            SetOptions(merge: true),
          );
      return true;
    } catch (_) {
      // For the prototype, remote failures must not break the local loop.
      return false;
    }
  }
}

class _RemoteContext {
  const _RemoteContext({required this.familyId, required this.deviceRole});

  final String familyId;
  final String deviceRole;
}

class ProtectionAlertRepository {
  ProtectionAlertRepository._({
    LocalDb? localDb,
    ProtectionAlertRemoteSink? remoteSink,
  }) : _localDb = localDb ?? LocalDb.instance,
       _remoteSink = remoteSink ?? FirestoreProtectionAlertRemoteSink();

  static final ProtectionAlertRepository instance =
      ProtectionAlertRepository._();

  final LocalDb _localDb;
  final ProtectionAlertRemoteSink _remoteSink;

  static const String _tableName = 'pending_events';

  Future<Database> get _db async => _localDb.database;

  /// Inserts or replaces an alert in the local queue and attempts a
  /// best-effort remote sync.
  Future<void> saveAlert(GuardianProtectionAlert alert) async {
    final db = await _db;
    await db.insert(
      _tableName,
      alert.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _syncUnsyncedToRemote();
  }

  /// Loads alerts for the child-facing surface.
  ///
  /// Results are ordered by `createdAt` descending by default.
  Future<List<GuardianProtectionAlert>> listAlerts({
    GuardianProtectionAlertStatus? status,
    int? limit,
    bool newestFirst = true,
  }) async {
    final db = await _db;
    final localRows = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: <Object>[GuardianProtectionAlert.typeChildAlert],
      orderBy: 'created_at ${newestFirst ? 'DESC' : 'ASC'}',
      limit: limit,
    );

    final alerts = localRows
        .map(GuardianProtectionAlert.fromDbRow)
        .toList(growable: true);

    final remoteAlerts = await _loadRemoteAlerts(limit: limit);
    if (remoteAlerts.isNotEmpty) {
      for (final alert in remoteAlerts) {
        final existingIndex = alerts.indexWhere((item) => item.id == alert.id);
        if (existingIndex >= 0) {
          final existing = alerts[existingIndex];
          alerts[existingIndex] = existing.synced ? alert : existing;
        } else {
          alerts.add(alert);
        }
        await db.insert(
          _tableName,
          alert.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.update(
          _tableName,
          <String, Object?>{'synced': 1},
          where: 'id = ?',
          whereArgs: <Object>[alert.id],
        );
      }
      alerts.sort((a, b) => newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt));
    }

    if (status == null) {
      return alerts;
    }

    return alerts
        .where((alert) => alert.status == status)
        .toList(growable: false);
  }

  Future<List<GuardianProtectionAlert>> _loadRemoteAlerts({int? limit}) async {
    final ctx = await _resolveReadContext();
    if (ctx == null) {
      return const <GuardianProtectionAlert>[];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('guardian_families')
          .doc(ctx.familyId)
          .collection('protection_alerts')
          .orderBy('createdAtMs', descending: true)
          .limit(limit ?? 50)
          .get();

      return snapshot.docs
          .map((doc) => GuardianProtectionAlert.fromRemoteMap(doc.data()))
          .where((alert) => alert.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <GuardianProtectionAlert>[];
    }
  }

  Future<_RemoteContext?> _resolveReadContext() async {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final familyId =
        prefs.getString('pair_id') ??
        prefs.getString('guardian_family_id') ??
        prefs.getString('pairing_code');

    if (familyId == null || familyId.isEmpty) {
      return null;
    }

    final userRole = prefs.getString('user_role') ?? 'child';
    return _RemoteContext(familyId: familyId, deviceRole: userRole);
  }

  /// Marks an alert as seen (but not fully resolved) on the child side.
  Future<void> markSeen(String id) async {
    await _updateStatus(id, GuardianProtectionAlertStatus.seen);
  }

  /// Marks an alert as resolved on the child side.
  Future<void> markResolved(String id) async {
    await _updateStatus(id, GuardianProtectionAlertStatus.resolved);
  }

  Future<void> _updateStatus(
    String id,
    GuardianProtectionAlertStatus status,
  ) async {
    final db = await _db;
    final rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }

    final current = GuardianProtectionAlert.fromDbRow(rows.first);
    final updated = current.copyWith(status: status, synced: false);

    await db.insert(
      _tableName,
      updated.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _syncUnsyncedToRemote();
  }

  Future<void> _syncUnsyncedToRemote() async {
    final db = await _db;
    final rows = await db.query(
      _tableName,
      where: 'type = ? AND synced = 0',
      whereArgs: <Object>[GuardianProtectionAlert.typeChildAlert],
      orderBy: 'created_at ASC',
    );

    if (rows.isEmpty) {
      return;
    }

    for (final row in rows) {
      final alert = GuardianProtectionAlert.fromDbRow(row);
      final pushed = await _remoteSink.pushAlert(alert);
      if (!pushed) {
        continue;
      }
      await db.update(
        _tableName,
        <String, Object?>{'synced': 1},
        where: 'id = ?',
        whereArgs: <Object>[alert.id],
      );
    }
  }
}
