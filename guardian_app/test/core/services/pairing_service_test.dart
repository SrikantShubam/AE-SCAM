import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/pairing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('generatePairingCode returns 6 chars from allowed alphabet only', () {
    const allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    for (var i = 0; i < 500; i++) {
      final code = PairingService.generatePairingCode();
      expect(code.length, 6);
      for (final ch in code.split('')) {
        expect(allowed.contains(ch), isTrue, reason: 'Unexpected char: $ch');
      }
      expect(code.contains('I'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('1'), isFalse);
    }
  });

  test('sanitizeCode strips separators and normalizes case', () {
    final service = PairingService();
    expect(service.sanitizeCode(' ab-23 cd '), 'AB23CD');
  });

  test('createCaregiverCode materializes the pair root document', () async {
    final firestore = FakeFirebaseFirestore();
    final prefs = await SharedPreferences.getInstance();
    final service = PairingService(
      firestore: firestore,
      prefs: prefs,
      currentAuthUidProvider: () async => 'caregiver-uid-1',
    );

    final result = await service.createCaregiverCode();

    expect(result.isSuccess, isTrue);
    final pairId = result.pairId!;
    final pairSnapshot = await firestore.collection('pairs').doc(pairId).get();
    final pairData = pairSnapshot.data();
    expect(pairSnapshot.exists, isTrue);
    expect(pairData?['pair_id'], pairId);
    expect(pairData?['caregiver_uid'], 'caregiver-uid-1');
    expect(pairData?['caregiver_device_id'], isNotEmpty);
    expect(pairData?['parent_device_id'], isNull);
    expect(pairData?['parent_uid'], isNull);
    expect(
      (pairData?['settings'] as Map<String, dynamic>)['emergency_disabled'],
      isFalse,
    );
  });

  test('claimParentCode attaches the parent device to the pair root document', () async {
    final firestore = FakeFirebaseFirestore();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final caregiverPrefs = await SharedPreferences.getInstance();
    final caregiverService = PairingService(
      firestore: firestore,
      prefs: caregiverPrefs,
      currentAuthUidProvider: () async => 'caregiver-uid-1',
    );
    final draft = await caregiverService.createCaregiverCode();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final parentPrefs = await SharedPreferences.getInstance();
    final parentService = PairingService(
      firestore: firestore,
      prefs: parentPrefs,
      currentAuthUidProvider: () async => 'parent-uid-9',
    );

    final claim = await parentService.claimParentCode(draft.code!);

    expect(claim.isSuccess, isTrue);
    final pairSnapshot = await firestore
        .collection('pairs')
        .doc(draft.pairId!)
        .get();
    final pairData = pairSnapshot.data();
    expect(pairData?['parent_device_id'], isNotEmpty);
    expect(pairData?['caregiver_device_id'], isNotEmpty);
    expect(pairData?['caregiver_uid'], 'caregiver-uid-1');
    expect(pairData?['parent_uid'], 'parent-uid-9');
  });

  test('createCaregiverCode rollback leaves no orphan pairing code when commit fails', () async {
    final firestore = FakeFirebaseFirestore();
    final prefs = await SharedPreferences.getInstance();
    final service = PairingService(
      firestore: firestore,
      prefs: prefs,
      currentAuthUidProvider: () async => 'caregiver-uid-1',
      onBeforeCreateCommit: () => throw StateError('forced-create-failure'),
    );

    final result = await service.createCaregiverCode();

    expect(result.isSuccess, isFalse);
    expect(result.reason, PairingFailureReason.offline);
    final pairingDocs = await firestore.collection('pairing').get();
    final pairDocs = await firestore.collection('pairs').get();
    expect(pairingDocs.docs, isEmpty);
    expect(pairDocs.docs, isEmpty);
  });

  test('claimParentCode rollback keeps code pending when pair hydration fails', () async {
    final firestore = FakeFirebaseFirestore();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final caregiverPrefs = await SharedPreferences.getInstance();
    final caregiverService = PairingService(
      firestore: firestore,
      prefs: caregiverPrefs,
      currentAuthUidProvider: () async => 'caregiver-uid-1',
    );
    final draft = await caregiverService.createCaregiverCode();
    expect(draft.isSuccess, isTrue);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final parentPrefs = await SharedPreferences.getInstance();
    final parentService = PairingService(
      firestore: firestore,
      prefs: parentPrefs,
      currentAuthUidProvider: () async => 'parent-uid-9',
      onBeforeClaimCommit: () => throw StateError('forced-claim-failure'),
    );

    final claim = await parentService.claimParentCode(draft.code!);

    expect(claim.isSuccess, isFalse);
    expect(claim.reason, PairingFailureReason.offline);
    final pairingSnapshot = await firestore.collection('pairing').doc(draft.code!).get();
    final pairingData = pairingSnapshot.data()!;
    expect(pairingData['status'], 'pending');
    expect(pairingData['claimed_at_ms'], isNull);
    expect(pairingData['claimed_by_device_id'], isNull);

    final pairSnapshot = await firestore.collection('pairs').doc(draft.pairId!).get();
    final pairData = pairSnapshot.data()!;
    expect(pairData['parent_device_id'], isNull);
    expect(pairData['parent_uid'], isNull);
  });
}
