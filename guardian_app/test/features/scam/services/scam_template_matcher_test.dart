import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/models/scam_template.dart';
import 'package:guardian/features/scam/services/scam_template_matcher.dart';
import 'package:test/test.dart';

void main() {
  group('ScamTemplateMatcher', () {
    test('matches bank impersonation pattern and returns alert severity', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text:
            'Your account statement is ready. Verify account now to avoid suspension.',
        senderId: 'BANK-ALRT',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-bank-1');
      expect(result.category, 'bank_impersonation');
      expect(result.severity, ScamSeverity.alert);
    });

    test('matches bank impersonation by keyword_all fallback', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Your account review is pending. Please complete review now.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-bank-kw-2');
      expect(result.category, 'bank_impersonation');
      expect(result.severity, ScamSeverity.warn);
    });

    test('matches courier template using regex path', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text:
            'Delivery failed due to address mismatch. Reschedule your delivery today.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-courier-1');
      expect(result.category, 'courier');
      expect(result.severity, ScamSeverity.warn);
    });

    test('matches courier template by keyword_any_of when regex misses', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Delivery issue detected. Confirm this immediately.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-courier-kw-2');
      expect(result.category, 'courier');
      expect(result.severity, ScamSeverity.warn);
    });

    test('matches kyc template and returns alert severity', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Paytm KYC expired. Complete KYC now or account will be blocked.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-kyc-1');
      expect(result.category, 'kyc_update');
      expect(result.severity, ScamSeverity.alert);
    });

    test('matches kyc keyword fallback when pattern does not match', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Your kyc is pending. Verify this today.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-kyc-kw-2');
      expect(result.category, 'kyc_update');
      expect(result.severity, ScamSeverity.warn);
    });

    test('matches reward template with regex and returns warn', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'You won a prize draw. Claim your reward cash now.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-reward-1');
      expect(result.category, 'reward_cashback');
      expect(result.severity, ScamSeverity.warn);
    });

    test('matches reward template keyword fallback with any-of semantics', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Winner selected. Your prize award is ready.',
        templates: _seedTemplates,
      );

      expect(result.matched, isTrue);
      expect(result.templateId, 'en-reward-kw-2');
      expect(result.category, 'reward_cashback');
      expect(result.severity, ScamSeverity.info);
    });

    test('returns unmatched info result when no template matches', () {
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'Tea at 5 PM tomorrow at home.',
        templates: _seedTemplates,
      );

      expect(result.matched, isFalse);
      expect(result.templateId, isNull);
      expect(result.category, isNull);
      expect(result.severity, ScamSeverity.info);
      expect(
        result.reason,
        'This message looks suspicious. We\'re not sure, so please check with your caregiver.',
      );
    });

    test('skips invalid regex patterns and logs warning', () {
      final warnings = <String>[];
      final result = ScamTemplateMatcher.matchAgainstTemplates(
        text: 'normal text',
        templates: <ScamTemplate>[
          ScamTemplate(
            id: 'bad-regex',
            category: 'bank_impersonation',
            language: 'en',
            regexPatterns: const <String>['[invalid'],
            keywordAll: const <String>[],
            keywordAnyOf: const <String>[],
            severity: ScamSeverity.warn,
            reason:
                'This message looks suspicious. We\'re not sure, so please check with your caregiver.',
            enabled: true,
            updatedAtMs: 1,
          ),
        ],
        onRegexWarning: warnings.add,
      );

      expect(result.matched, isFalse);
      expect(warnings, hasLength(1));
      expect(warnings.first, contains('Skipping invalid scam regex pattern'));
    });
  });
}

final List<ScamTemplate> _seedTemplates = <ScamTemplate>[
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
    updatedAtMs: 1000,
  ),
  ScamTemplate(
    id: 'en-bank-kw-2',
    category: 'bank_impersonation',
    language: 'en',
    regexPatterns: <String>['\\bbank\\s+notice\\b'],
    keywordAll: <String>['account', 'review'],
    keywordAnyOf: const <String>[],
    severity: ScamSeverity.warn,
    reason:
        'This message looks suspicious for bank-account requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1001,
  ),
  ScamTemplate(
    id: 'en-courier-1',
    category: 'courier',
    language: 'en',
    regexPatterns: <String>[
      '(?=.*\\bdelivery\\b)(?=.*\\b(?:address|reschedule)\\b).+',
    ],
    keywordAll: <String>['delivery', 'address'],
    keywordAnyOf: <String>['reschedule', 'track'],
    severity: ScamSeverity.warn,
    reason:
        'This message looks suspicious for delivery or courier requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1002,
  ),
  ScamTemplate(
    id: 'en-courier-kw-2',
    category: 'courier',
    language: 'en',
    regexPatterns: <String>['\\bcourier\\s+support\\b'],
    keywordAll: <String>['delivery', 'issue'],
    keywordAnyOf: <String>['confirm', 'immediately'],
    severity: ScamSeverity.warn,
    reason:
        'This message looks suspicious for delivery or courier requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1003,
  ),
  ScamTemplate(
    id: 'en-kyc-1',
    category: 'kyc_update',
    language: 'en',
    regexPatterns: <String>['\\bpaytm\\s+kyc\\b'],
    keywordAll: <String>['paytm', 'kyc'],
    keywordAnyOf: const <String>[],
    severity: ScamSeverity.alert,
    reason:
        'This message looks suspicious for KYC update requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1004,
  ),
  ScamTemplate(
    id: 'en-kyc-kw-2',
    category: 'kyc_update',
    language: 'en',
    regexPatterns: <String>['\\bverification\\s+portal\\b'],
    keywordAll: <String>['kyc', 'pending'],
    keywordAnyOf: <String>['verify', 'today'],
    severity: ScamSeverity.warn,
    reason:
        'This message looks suspicious for KYC update requests. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1005,
  ),
  ScamTemplate(
    id: 'en-reward-1',
    category: 'reward_cashback',
    language: 'en',
    regexPatterns: <String>[
      '(?:(?=.*\\b(?:draw|entry)\\b)(?=.*\\b(?:win|cash|prize)\\b).+)',
    ],
    keywordAll: <String>['draw', 'win'],
    keywordAnyOf: <String>['quiz', 'cash'],
    severity: ScamSeverity.warn,
    reason:
        'This message looks suspicious for reward or cashback offers. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1006,
  ),
  ScamTemplate(
    id: 'en-reward-kw-2',
    category: 'reward_cashback',
    language: 'en',
    regexPatterns: <String>['\\bpromo\\s+club\\b'],
    keywordAll: <String>['winner', 'prize'],
    keywordAnyOf: <String>['lottery', 'award'],
    severity: ScamSeverity.info,
    reason:
        'This message looks suspicious for reward or cashback offers. We\'re not sure, so please check with your caregiver.',
    enabled: true,
    updatedAtMs: 1007,
  ),
];
