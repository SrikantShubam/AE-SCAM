import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/models/scam_template.dart';
import 'package:guardian/features/scam/services/scam_share_intent_processor.dart';
import 'package:test/test.dart';

void main() {
  group('ScamShareIntentProcessor', () {
    test('returns null when shared text is empty', () {
      final verdict = ScamShareIntentProcessor.evaluate(
        sharedText: '   ',
        templates: _templates,
      );

      expect(verdict, isNull);
    });

    test('returns matched verdict for matching share text', () {
      final verdict = ScamShareIntentProcessor.evaluate(
        sharedText: 'Please update your account statement now.',
        templates: _templates,
      );

      expect(verdict, isNotNull);
      expect(verdict!.sharedText, 'Please update your account statement now.');
      expect(verdict.result.matched, isTrue);
      expect(verdict.result.category, 'bank_impersonation');
      expect(verdict.result.severity, ScamSeverity.alert);
    });

    test('returns unmatched verdict when templates do not match', () {
      final verdict = ScamShareIntentProcessor.evaluate(
        sharedText: 'Bring milk on the way home.',
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
