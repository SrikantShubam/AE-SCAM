import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readRules() => File('firestore.rules').readAsStringSync();

  test('pairs rules cover the live devices subcollection', () {
    final rules = readRules();

    expect(
      rules,
      contains(
        "match /devices/{deviceId} {\n"
        "        allow read: if isPairMember(pairId);",
      ),
    );
  });

  test('pairs rules bind pair membership to pair-root auth uids', () {
    final rules = readRules();

    expect(rules, contains('pairDoc(pairId).data.caregiver_uid == request.auth.uid'));
    expect(rules, contains('pairDoc(pairId).data.parent_uid == request.auth.uid'));
    expect(rules, contains('return isCaregiver(pairId) || isParent(pairId);'));
  });

  test('pairs rules preserve parent-only writes for medication and payment events', () {
    final rules = readRules();

    expect(
      rules,
      contains(
        "match /medication_events/{eventId} {\n"
        "        allow read: if isPairMember(pairId);\n"
        "        allow create, update: if isParent(pairId);",
      ),
    );
    expect(
      rules,
      contains(
        "match /payment_events/{eventId} {\n"
        "        allow read: if isPairMember(pairId);\n"
        "        allow create, update: if isParent(pairId);",
      ),
    );
  });

  test('pairing claim delete requires parent link in same transaction', () {
    final rules = readRules();

    expect(
      rules,
      contains(
        "allow delete: if signedIn()\n"
        "        && resource.data.pair_id is string\n"
        "        && resource.data.claimed_at_ms == null\n"
        "        && resource.data.claimed_by_device_id == null",
      ),
    );
    expect(
      rules,
      contains(
        "getAfter(/databases/\$(database)/documents/pairs/\$(resource.data.pair_id)).data.parent_uid == request.auth.uid",
      ),
    );
    expect(
      rules,
      contains(
        "getAfter(/databases/\$(database)/documents/pairs/\$(resource.data.pair_id)).data.parent_device_id is string",
      ),
    );
    expect(rules, isNot(contains("match /pairing/{code} {\n      allow delete: if false;")));
  });
}
