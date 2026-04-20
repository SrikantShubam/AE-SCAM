import 'dart:io';

import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/models/scam_template.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('parses real seed bundle schema into runtime templates', () async {
    final file = File(
      p.join(
        Directory.current.path,
        'assets',
        'scam_templates',
        'seed_en.json',
      ),
    );
    final jsonString = await file.readAsString();

    final bundle = ScamTemplate.parseSeedBundleJson(jsonString);
    final templates = bundle.templates;

    expect(templates, isNotEmpty);
    expect(templates.length, 6);
    expect(bundle.version, '1.0');
    expect(bundle.sourceCorpus, 'seed_pool_v0_1.csv');
    expect(bundle.corpusScamRowCount, 1874);
    expect(
      bundle.generatedAt.toIso8601String(),
      startsWith('2026-04-18T18:34:03'),
    );

    final first = templates.first;
    expect(first.id, 'en-bank_impersonation-account-statement-1');
    expect(first.category, 'bank_impersonation');
    expect(first.language, 'en');
    expect(first.regexPatterns, hasLength(1));
    expect(first.regexPatterns.first, contains('account'));
    expect(first.keywordAll, containsAll(<String>['account', 'statement']));
    expect(first.keywordAnyOf, isEmpty);
    expect(first.enabled, isTrue);
    expect(first.updatedAtMs, greaterThan(0));
    expect(first.severity, ScamSeverity.alert);
    expect(first.reason, contains('looks suspicious'));
    expect(first.reason.toLowerCase(), contains('we\'re not sure'));
    expect(first.reason, contains('please check with your caregiver'));
    expect(first.precision, closeTo(1.0, 0.00001));
    expect(first.recall, closeTo(0.7273, 0.00001));
    expect(first.exampleMatches.length, greaterThan(0));
    expect(first.notes, isNotNull);
  });

  test('skips malformed template records and emits validation warnings', () {
    const malformedSeed = '''
{
  "generated_at":"2026-04-18T18:34:03Z",
  "templates":[
    {"id":"", "category":"bank_impersonation","pattern":"x"},
    {"id":"en-ok-1","category":"courier","pattern":"delivery","keyword_all":["delivery"]},
    "not-an-object"
  ]
}
''';

    final warnings = <String>[];
    final templates = ScamTemplate.fromSeedBundleJson(
      malformedSeed,
      onValidationWarning: warnings.add,
    );

    expect(templates, hasLength(1));
    expect(templates.first.id, 'en-ok-1');
    expect(warnings.length, 2);
  });
}
