import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/protection/models/payment_protection_snapshot.dart';

void main() {
  test('payment protection snapshot maps a high-risk platform payload into a red warning state', () {
    final warning = PaymentProtectionSnapshot.fromPlatform(<String, dynamic>{
      'serviceEnabled': true,
      'state': 'red',
      'reasons': <String>[
        'Payment flow detected in Google Pay.',
      ],
      'lastMonitoredPackageName': 'com.google.android.apps.nbu.paisa.user',
      'lastMonitoredAppLabel': 'Google Pay',
      'lastMonitoredAtMs': 1710000000000,
      'warningWindowMs': 60000,
      'paymentContextDetected': true,
      'matchedSignals': <String>['pay', 'upi', 'amount'],
      'detectedAmountHint': 'Rs 2,500',
      'detectedRecipientHint': 'Rakesh Kumar',
      'detectedUpiIdHint': 'rakesh@oksbi',
      'reviewTitle': 'Stop and check Rs 2,500 to Rakesh Kumar carefully',
      'reviewBody':
          'Guardian noticed a higher-risk payment flow in Google Pay showing recipient Rakesh Kumar, UPI ID rakesh@oksbi, amount Rs 2,500. The visible amount looks higher than a typical UPI transfer. Pause, verify who asked for this payment, and only continue if the details are fully expected.',
      'cooldownSeconds': 30,
      'proceedLabel': 'Yes, continue after cooldown',
      'safeExitLabel': 'No, go back to safety',
      'hasHighAmount': true,
      'hasSuspiciousLanguage': false,
      'recipientRecentlyChanged': false,
      'recipientKnown': false,
      'escalationRecommended': true,
      'escalationReason':
          'Ask a family member before paying a recipient Guardian has not seen confirmed before.',
      'lastEscalationEventId': 'escalation-1710000001000',
      'lastEscalationAtMs': 1710000001000,
      'lastEscalationAppLabel': 'Google Pay',
      'lastEscalationTitle': 'Stop and verify this new payment recipient',
      'lastEscalationBody':
          'Guardian noticed a higher-risk payment flow in Google Pay showing recipient Rakesh Kumar, UPI ID rakesh@oksbi, amount Rs 2,500. Guardian has not seen this recipient confirmed before. Pause, verify who asked for this payment, and only continue if the details are fully expected.',
      'lastEscalationAmountHint': 'Rs 2,500',
      'lastEscalationRecipientHint': 'Rakesh Kumar',
      'lastEscalationUpiIdHint': 'rakesh@oksbi',
      'lastEscalationPending': true,
    });

    expect(warning.isWarning, isTrue);
    expect(warning.isRed, isTrue);
    expect(warning.serviceEnabled, isTrue);
    expect(warning.lastMonitoredAppLabel, 'Google Pay');
    expect(warning.reasons, hasLength(1));
    expect(warning.paymentContextDetected, isTrue);
    expect(warning.matchedSignals, containsAll(<String>['pay', 'upi', 'amount']));
    expect(warning.detectedAmountHint, 'Rs 2,500');
    expect(warning.detectedRecipientHint, 'Rakesh Kumar');
    expect(warning.detectedUpiIdHint, 'rakesh@oksbi');
    expect(
      warning.reviewTitle,
      'Stop and check Rs 2,500 to Rakesh Kumar carefully',
    );
    expect(
      warning.reviewBody,
      'Guardian noticed a higher-risk payment flow in Google Pay showing recipient Rakesh Kumar, UPI ID rakesh@oksbi, amount Rs 2,500. The visible amount looks higher than a typical UPI transfer. Pause, verify who asked for this payment, and only continue if the details are fully expected.',
    );
    expect(warning.cooldownSeconds, 30);
    expect(warning.proceedLabel, 'Yes, continue after cooldown');
    expect(warning.safeExitLabel, 'No, go back to safety');
    expect(warning.hasHighAmount, isTrue);
    expect(warning.hasSuspiciousLanguage, isFalse);
    expect(warning.recipientRecentlyChanged, isFalse);
    expect(warning.isRecipientKnown, isFalse);
    expect(warning.isNewRecipient, isTrue);
    expect(warning.escalationRecommended, isTrue);
    expect(
      warning.escalationReason,
      'Ask a family member before paying a recipient Guardian has not seen confirmed before.',
    );
    expect(warning.lastEscalationEventId, 'escalation-1710000001000');
    expect(warning.lastEscalationAppLabel, 'Google Pay');
    expect(warning.lastEscalationTitle, 'Stop and verify this new payment recipient');
    expect(warning.lastEscalationRecipientHint, 'Rakesh Kumar');
    expect(warning.lastEscalationPending, isTrue);
    expect(warning.hasElevatedRiskSignals, isTrue);

    final inactive = PaymentProtectionSnapshot.fromPlatform(null);
    expect(inactive.isInactive, isTrue);
    expect(inactive.serviceEnabled, isFalse);
  });

  test('payment protection snapshot reports no elevated risk when all risk booleans are false', () {
    final monitoring = PaymentProtectionSnapshot.fromPlatform(<String, dynamic>{
      'serviceEnabled': true,
      'state': 'monitoring',
      'reasons': <String>['Live payment protection is on.'],
      'lastMonitoredPackageName': 'com.google.android.apps.nbu.paisa.user',
      'lastMonitoredAppLabel': 'Google Pay',
      'lastMonitoredAtMs': 1710000000000,
      'warningWindowMs': 60000,
      'paymentContextDetected': true,
      'matchedSignals': <String>['pay'],
      'hasHighAmount': false,
      'hasSuspiciousLanguage': false,
      'recipientRecentlyChanged': false,
      'recipientKnown': true,
      'escalationRecommended': false,
      'lastEscalationPending': false,
    });

    expect(monitoring.isMonitoring, isTrue);
    expect(monitoring.serviceEnabled, isTrue);
    expect(monitoring.hasHighAmount, isFalse);
    expect(monitoring.hasSuspiciousLanguage, isFalse);
    expect(monitoring.recipientRecentlyChanged, isFalse);
    expect(monitoring.isRecipientKnown, isTrue);
    expect(monitoring.isNewRecipient, isFalse);
    expect(monitoring.escalationRecommended, isFalse);
    expect(monitoring.escalationReason, isNull);
    expect(monitoring.lastEscalationPending, isFalse);
    expect(monitoring.hasElevatedRiskSignals, isFalse);
  });
}
