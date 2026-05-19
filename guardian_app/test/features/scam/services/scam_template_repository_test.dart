import 'package:guardian/core/services/local_db.dart';
import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/models/scam_template.dart';
import 'package:guardian/features/scam/services/scam_template_repository.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  late LocalDb localDb;
  late ScamTemplateRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    localDb = LocalDb.test(
      databasePath: inMemoryDatabasePath,
      databaseFactory: databaseFactoryFfi,
    );
    repository = ScamTemplateRepository(localDb: localDb);
    await repository.upsertTemplates(<ScamTemplate>[
      ScamTemplate(
        id: 'en-seed-1',
        category: 'bank_impersonation',
        language: 'en',
        regexPatterns: const <String>['\\baccount\\s+statement\\b'],
        keywordAll: const <String>['account', 'statement'],
        keywordAnyOf: const <String>[],
        severity: ScamSeverity.alert,
        reason: 'Looks suspicious.',
        enabled: true,
        updatedAtMs: 1,
      ),
    ]);
  });

  tearDown(() async {
    await localDb.close();
  });

  test('returns no templates when locale bucket is empty', () async {
    final templates = await repository.listEnabledTemplatesByLanguage('hi-IN');

    expect(templates, isEmpty);
  });

  test('returns direct language matches when present', () async {
    await repository.upsertTemplates(<ScamTemplate>[
      ScamTemplate(
        id: 'hi-seed-1',
        category: 'bank_impersonation',
        language: 'hi',
        regexPatterns: const <String>['account'],
        keywordAll: const <String>['account'],
        keywordAnyOf: const <String>[],
        severity: ScamSeverity.warn,
        reason: 'Looks suspicious.',
        enabled: true,
        updatedAtMs: 2,
      ),
    ]);

    final templates = await repository.listEnabledTemplatesByLanguage('hi-IN');

    expect(templates, hasLength(1));
    expect(templates.first.id, 'hi-seed-1');
  });
}
