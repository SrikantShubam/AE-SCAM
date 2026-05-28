import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/protection/services/emergency_disable_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyFcmDataPayload stores emergency disabled true', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await EmergencyDisableSyncService.applyFcmDataPayload(<String, dynamic>{
      'event_type': 'emergency_disable_changed',
      'emergency_disabled': 'true',
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('emergency_disabled'), isTrue);
  });

  test('applyFcmDataPayload ignores unrelated events', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'emergency_disabled': false,
    });

    await EmergencyDisableSyncService.applyFcmDataPayload(<String, dynamic>{
      'event_type': 'other_event',
      'emergency_disabled': 'true',
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('emergency_disabled'), isFalse);
  });

  test('toggleFromCaregiver writes settings.emergency_disabled to pairs doc', () async {
    final firestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pair_id': 'pair-123',
      'user_role': 'child',
      'emergency_disabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = EmergencyDisableSyncService(
      firestore: firestore,
      prefs: prefs,
    );

    final toggled = await service.toggleFromCaregiver();

    final snapshot = await firestore.collection('pairs').doc('pair-123').get();
    expect(toggled, isTrue);
    expect(
      (snapshot.data()?['settings'] as Map<String, dynamic>)['emergency_disabled'],
      isTrue,
    );
    expect(prefs.getBool('emergency_disabled'), isTrue);
  });

  test('start syncs parent emergency disable updates from pairs document', () async {
    final firestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pair_id': 'pair-abc',
      'user_role': 'parent',
      'guardian_device_id': 'device-parent-1',
      'emergency_disabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = EmergencyDisableSyncService(
      firestore: firestore,
      prefs: prefs,
    );

    await service.start();
    await firestore.collection('pairs').doc('pair-abc').set(<String, dynamic>{
      'settings': <String, dynamic>{'emergency_disabled': true},
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(prefs.getBool('emergency_disabled'), isTrue);
    await service.dispose();
  });

  test('start registers the parent device token under pairs devices', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('pairs').doc('pair-live').set(<String, dynamic>{
      'pair_id': 'pair-live',
      'caregiver_uid': 'caregiver-uid-1',
      'parent_uid': 'parent-uid-7',
      'caregiver_device_id': 'device-caregiver-1',
      'parent_device_id': 'device-parent-9',
      'created_at_ms': 1,
      'updated_at_ms': 1,
      'settings': <String, dynamic>{'emergency_disabled': false},
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pair_id': 'pair-live',
      'user_role': 'parent',
      'guardian_device_id': 'device-parent-9',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = EmergencyDisableSyncService(
      firestore: firestore,
      prefs: prefs,
      fcmTokenProvider: () async => 'token-parent-9',
    );

    await service.start();

    final snapshot = await firestore
        .collection('pairs')
        .doc('pair-live')
        .collection('devices')
        .doc('device-parent-9')
        .get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['role'], 'parent');
    expect(snapshot.data()?['fcm_token'], 'token-parent-9');
    await service.dispose();
  });
}
