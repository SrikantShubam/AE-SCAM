import 'package:flutter/foundation.dart';

enum ConsentType {
  dpdpa,
  // gdpr,
  // ccpa,
}

@immutable
class ConsentContent {
  const ConsentContent({
    required this.type,
    required this.consentVersion,
    required this.title,
    required this.introduction,
    required this.dataCollectedHeading,
    required this.dataCollectedPoints,
    required this.dataProtectionHeading,
    required this.dataProtectionPoints,
    required this.userRightsHeading,
    required this.userRightsPoints,
    required this.checkboxLabel,
    required this.continueLabel,
    required this.privacyPolicyLabel,
    required this.alreadyRecordedLabel,
    required this.alreadyRecordedSubtitle,
  });

  final ConsentType type;
  final String consentVersion;
  final String title;
  final String introduction;
  final String dataCollectedHeading;
  final List<String> dataCollectedPoints;
  final String dataProtectionHeading;
  final List<String> dataProtectionPoints;
  final String userRightsHeading;
  final List<String> userRightsPoints;
  final String checkboxLabel;
  final String continueLabel;
  final String privacyPolicyLabel;
  final String alreadyRecordedLabel;
  final String alreadyRecordedSubtitle;

  const ConsentContent.dpdpa()
      : type = ConsentType.dpdpa,
        consentVersion = '2026-04-01-v1',
        title = 'Your Data, Your Control',
        introduction =
            'Guardian needs your explicit permission before it stores or uses elder-care and protection data.',
        dataCollectedHeading = 'What we collect and why',
        dataCollectedPoints = const [
          'Medication schedules and adherence, so we can send reminders and keep your family informed.',
          'Health reading images, so you can store them for doctor visits without automatic analysis.',
          'Payment app activity, so Guardian can detect and warn about possible scams.',
          'App usage patterns, so Guardian can understand when payment protection is being used.',
        ],
        dataProtectionHeading = 'How your data is protected',
        dataProtectionPoints = const [
          'Your data is encrypted in transit and at rest wherever the platform supports it.',
          'Your data is never sold or shared with advertisers.',
          'Your family guardian can only see what you have agreed to share.',
        ],
        userRightsHeading = 'Your rights',
        userRightsPoints = const [
          'You can withdraw consent at any time in Settings.',
          'You can request deletion of your data.',
          'You can ask us what data we hold about you.',
        ],
        checkboxLabel =
            'I understand and consent to the data collection described above.',
        continueLabel = 'Continue',
        privacyPolicyLabel = 'Read full privacy policy',
        alreadyRecordedLabel = 'Consent already recorded',
        alreadyRecordedSubtitle =
            'This device already has a valid consent record for the current version.';

  factory ConsentContent.forConsentType(Object? consentType) {
    switch (consentType) {
      case ConsentType.dpdpa:
      case null:
      default:
        return const ConsentContent.dpdpa();
    }
  }
}
