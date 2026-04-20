import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/models/scam_notification_input.dart';
import 'package:guardian/features/scam/models/scam_template.dart';
import 'package:guardian/features/scam/services/scam_notification_intent_processor.dart';
import 'package:test/test.dart';

void main() {
  group('ScamNotificationIntentProcessor', () {
    test('returns null when input is missing', () {
      final verdict = ScamNotificationIntentProcessor.evaluate(
        input: null,
        templates: _templates,
      );

      expect(verdict, isNull);
    });

    test('returns matched verdict for monitored notification payload', () {
      const input = ScamNotificationInput(
        sourcePackage: 'com.whatsapp',
        sender: 'BANK-ALERT',
        messageBody: 'Your account statement is pending. Verify now.',
        receivedAtMs: 123,
      );

      final verdict = ScamNotificationIntentProcessor.evaluate(
        input: input,
        templates: _templates,
      );

      expect(verdict, isNotNull);
      expect(verdict!.result.matched, isTrue);
      expect(verdict.result.category, 'bank_impersonation');
      expect(verdict.result.severity, ScamSeverity.alert);
    });

    test('returns unmatched verdict when notification does not match', () {
      const input = ScamNotificationInput(
        sourcePackage: 'com.whatsapp',
        sender: 'Friend',
        messageBody: 'Tea at 5pm tomorrow.',
        receivedAtMs: 123,
      );

      final verdict = ScamNotificationIntentProcessor.evaluate(
        input: input,
        templates: _templates,
      );

      expect(verdict, isNotNull);
      expect(verdict!.result.matched, isFalse);
      expect(verdict.result.severity, ScamSeverity.info);
      expect(verdict.result.reason.toLowerCase(), contains("we're not sure"));
    });
  });
}

final List<ScamTemplate> _templates = <ScamTemplate>[
  ScamTemplate(
    id: 'en-bank-1',
    category: 'bank_impersonation',
    language: 'en',
    regexPatterns: <String>['\\baccount\\s+statement\\b'],
    keywordAll: <String>['account', 'statement'],
    keywordAnyOf: const <String>[],
    severity: ScamSeverity.alert,
    reason:
        'This message looks suspicious for bank-account requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1,
  ),
];
