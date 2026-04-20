// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Guardian';

  @override
  String get homeTitle => 'Guardian';

  @override
  String get onboardingDisclosureTitle => 'What Guardian needs to protect you';

  @override
  String get onboardingDisclosureNeedPaymentAppsBullet1 =>
      'Read screen content in payment apps such as Google Pay, PhonePe, and Paytm to detect risky transactions.';

  @override
  String get onboardingDisclosureNeedMessagesBullet2 =>
      'Read supported payment-screen details to detect risky payment requests.';

  @override
  String get onboardingDisclosureNeedWarningsBullet3 =>
      'Show a safety warning before you complete a potentially dangerous payment.';

  @override
  String get onboardingDisclosureDoesNotDoTitle => 'What Guardian does not do';

  @override
  String get onboardingDisclosureDoesNotStoreBullet1 =>
      'Guardian does not store your payment details.';

  @override
  String get onboardingDisclosureDoesNotShareBullet2 =>
      'Guardian does not share your data with anyone.';

  @override
  String get onboardingDisclosureDoesNotBlockBullet3 =>
      'Guardian does not block payments. You always have the final say.';

  @override
  String get onboardingDisclosureTurnOffTitle =>
      'You can turn this off anytime';

  @override
  String get onboardingDisclosureTurnOffBody =>
      'Go to Settings > Accessibility > Guardian to disable protection.';

  @override
  String get onboardingDisclosureAgreeButton =>
      'Open Android Accessibility settings';

  @override
  String get onboardingDisclosureSkipLink => 'You can skip this step';

  @override
  String get onboardingConsentTitle => 'Your Data, Your Control';

  @override
  String get onboardingConsentWhatWeCollectTitle => 'What we collect and why';

  @override
  String get onboardingConsentCollectMedicationBullet1 =>
      'Medication schedules and adherence - to send reminders and keep your family informed.';

  @override
  String get onboardingConsentCollectHealthBullet2 =>
      'Health reading images - to store for doctor visits. We do not extract or analyse these.';

  @override
  String get onboardingConsentCollectPaymentBullet3 =>
      'Payment app activity - to detect and warn about potential scams.';

  @override
  String get onboardingConsentCollectUsageBullet4 =>
      'App usage patterns - to understand when payment protection is being used.';

  @override
  String get onboardingConsentHowProtectedTitle => 'How your data is protected';

  @override
  String get onboardingConsentProtectEncryptedBullet1 =>
      'Your data is encrypted in transit and at rest.';

  @override
  String get onboardingConsentProtectNotSoldBullet2 =>
      'Your data is never sold or shared with advertisers.';

  @override
  String get onboardingConsentProtectFamilyBullet3 =>
      'Your family guardian can only see what you have agreed to share.';

  @override
  String get onboardingConsentRightsTitle => 'Your rights';

  @override
  String get onboardingConsentRightsWithdrawBullet1 =>
      'You can withdraw consent at any time in Settings.';

  @override
  String get onboardingConsentRightsDeleteBullet2 =>
      'You can request deletion of all your data.';

  @override
  String get onboardingConsentRightsAccessBullet3 =>
      'You can ask us what data we hold about you.';

  @override
  String get onboardingConsentCheckboxLabel =>
      'I understand and consent to the data collection described above';

  @override
  String get onboardingConsentPrivacyPolicyLabel => 'Read full privacy policy';

  @override
  String get onboardingConsentContinueButton => 'Continue';

  @override
  String get onboardingRoleSelectTitle => 'Whose phone is this?';

  @override
  String get onboardingRoleSelectChildTitle => 'I am the child / guardian';

  @override
  String get onboardingRoleSelectChildSubtitle =>
      'Set up the account that helps and monitors the parent.';

  @override
  String get onboardingRoleSelectParentTitle => 'I am the parent / elder';

  @override
  String get onboardingRoleSelectParentSubtitle =>
      'Set up the account that receives help and protection.';

  @override
  String get onboardingRoleSelectChildCta => 'Choose child / guardian';

  @override
  String get onboardingRoleSelectParentCta => 'Choose parent / elder';
}
