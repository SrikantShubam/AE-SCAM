import 'package:sqflite/sqflite.dart';

import '../../../core/services/local_db.dart';
import '../models/scam_template.dart';

class ScamTemplateRepository {
  ScamTemplateRepository({required LocalDb localDb}) : _localDb = localDb;

  final LocalDb _localDb;
  static const String _tableName = 'scam_templates';

  Future<Database> get _db async => _localDb.database;

  Future<void> upsertTemplates(List<ScamTemplate> templates) async {
    if (templates.isEmpty) {
      return;
    }

    final db = await _db;
    final batch = db.batch();
    for (final template in templates) {
      batch.insert(
        _tableName,
        template.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertSeedBundleJson(
    String seedBundleJson, {
    void Function(String message)? onValidationWarning,
  }) async {
    final bundle = ScamTemplate.parseSeedBundleJson(
      seedBundleJson,
      onValidationWarning: onValidationWarning,
    );
    await upsertTemplates(bundle.templates);
  }

  Future<List<ScamTemplate>> listEnabledTemplatesByLanguage(
    String language,
  ) async {
    final db = await _db;
    final normalized = _normalizeLanguage(language);

    final rows = await db.query(
      _tableName,
      where: 'enabled = 1 AND language = ?',
      whereArgs: <Object?>[normalized],
      orderBy: 'updated_at DESC, id ASC',
    );
    return rows.map(ScamTemplate.fromDbRow).toList(growable: false);
  }

  String _normalizeLanguage(String language) {
    final trimmed = language.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'en';
    }
    final separatorIndex = trimmed.indexOf(RegExp(r'[-_]'));
    if (separatorIndex <= 0) {
      return trimmed;
    }
    return trimmed.substring(0, separatorIndex);
  }
}
