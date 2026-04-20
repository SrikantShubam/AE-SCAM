import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readArb(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return Map<String, dynamic>.from(decoded as Map);
}

Set<String> _messageKeys(Map<String, dynamic> arb) {
  return arb.keys
      .where((key) => !key.startsWith('@'))
      .cast<String>()
      .toSet();
}

void main() {
  test('Phase 0 ARB scaffolding covers English and Hindi onboarding copy', () {
    final en = _messageKeys(_readArb('lib/l10n/app_en.arb'));
    final hi = _messageKeys(_readArb('lib/l10n/app_hi.arb'));

    const expectedKeys = <String>{
      'appTitle',
      'homeTitle',
      'onboardingDisclosureTitle',
      'onboardingDisclosureNeedPaymentAppsBullet1',
      'onboardingDisclosureNeedMessagesBullet2',
      'onboardingDisclosureNeedWarningsBullet3',
      'onboardingDisclosureDoesNotDoTitle',
      'onboardingDisclosureDoesNotStoreBullet1',
      'onboardingDisclosureDoesNotShareBullet2',
      'onboardingDisclosureDoesNotBlockBullet3',
      'onboardingDisclosureTurnOffTitle',
      'onboardingDisclosureTurnOffBody',
      'onboardingDisclosureAgreeButton',
      'onboardingDisclosureSkipLink',
      'onboardingConsentTitle',
      'onboardingConsentWhatWeCollectTitle',
      'onboardingConsentCollectMedicationBullet1',
      'onboardingConsentCollectHealthBullet2',
      'onboardingConsentCollectPaymentBullet3',
      'onboardingConsentCollectUsageBullet4',
      'onboardingConsentHowProtectedTitle',
      'onboardingConsentProtectEncryptedBullet1',
      'onboardingConsentProtectNotSoldBullet2',
      'onboardingConsentProtectFamilyBullet3',
      'onboardingConsentRightsTitle',
      'onboardingConsentRightsWithdrawBullet1',
      'onboardingConsentRightsDeleteBullet2',
      'onboardingConsentRightsAccessBullet3',
      'onboardingConsentCheckboxLabel',
      'onboardingConsentPrivacyPolicyLabel',
      'onboardingConsentContinueButton',
      'onboardingRoleSelectTitle',
      'onboardingRoleSelectChildTitle',
      'onboardingRoleSelectChildSubtitle',
      'onboardingRoleSelectParentTitle',
      'onboardingRoleSelectParentSubtitle',
      'onboardingRoleSelectChildCta',
      'onboardingRoleSelectParentCta',
    };

    expect(en.length, expectedKeys.length);
    expect(hi.length, expectedKeys.length);
    expect(en, containsAll(expectedKeys));
    expect(hi, containsAll(expectedKeys));
    expect(en.difference(hi), isEmpty);
    expect(hi.difference(en), isEmpty);
  });
}
