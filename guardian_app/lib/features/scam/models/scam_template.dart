import 'dart:convert';

import 'scam_match_result.dart';

class ScamTemplate {
  const ScamTemplate({
    required this.id,
    required this.category,
    required this.language,
    required this.regexPatterns,
    required this.keywordAll,
    required this.keywordAnyOf,
    required this.severity,
    required this.reason,
    required this.enabled,
    required this.updatedAtMs,
    this.precision,
    this.recall,
    this.exampleMatches = const <String>[],
    this.notes,
  });

  final String id;
  final String category;
  final String language;
  final List<String> regexPatterns;
  final List<String> keywordAll;
  final List<String> keywordAnyOf;
  final ScamSeverity severity;
  final String reason;
  final bool enabled;
  final int updatedAtMs;
  final double? precision;
  final double? recall;
  final List<String> exampleMatches;
  final String? notes;

  Map<String, Object?> toDbRow() {
    return <String, Object?>{
      'id': id,
      'category': category,
      'language': language,
      'regex_patterns': jsonEncode(regexPatterns),
      'keyword_all': jsonEncode(keywordAll),
      'keyword_any_of': jsonEncode(keywordAnyOf),
      'precision': precision,
      'recall': recall,
      'example_matches': jsonEncode(exampleMatches),
      'notes': notes,
      'severity': severity.name,
      'reason': reason,
      'enabled': enabled ? 1 : 0,
      'updated_at': updatedAtMs,
    };
  }

  factory ScamTemplate.fromDbRow(Map<String, Object?> row) {
    return ScamTemplate(
      id: row['id'] as String,
      category: row['category'] as String,
      language: row['language'] as String,
      regexPatterns: _readStringList(row['regex_patterns']),
      keywordAll: _readStringList(row['keyword_all']),
      keywordAnyOf: _readStringList(row['keyword_any_of']),
      precision: _readDouble(row['precision']),
      recall: _readDouble(row['recall']),
      exampleMatches: _readStringList(row['example_matches']),
      notes: _readNullableString(row['notes']),
      severity: _severityFromName(row['severity'] as String?),
      reason: row['reason'] as String,
      enabled: (row['enabled'] as num?)?.toInt() == 1,
      updatedAtMs: (row['updated_at'] as num).toInt(),
    );
  }

  static List<String> _readStringList(Object? value) {
    if (value is! String || value.isEmpty) {
      return const <String>[];
    }
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      return const <String>[];
    }
    return decoded
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static ScamSeverity _severityFromName(String? value) {
    return ScamSeverity.values.firstWhere(
      (severity) => severity.name == value,
      orElse: () => ScamSeverity.info,
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String? _readNullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  static List<ScamTemplate> fromSeedBundleJson(
    String jsonString, {
    void Function(String message)? onValidationWarning,
  }) {
    return parseSeedBundleJson(
      jsonString,
      onValidationWarning: onValidationWarning,
    ).templates;
  }

  static ScamTemplateSeedBundle parseSeedBundleJson(
    String jsonString, {
    void Function(String message)? onValidationWarning,
  }) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Scam seed bundle must be a JSON object with templates[].',
      );
    }

    final templatesRaw = decoded['templates'];
    if (templatesRaw is! List) {
      throw const FormatException('Scam seed bundle is missing templates[].');
    }

    final version = (decoded['version'] as String? ?? '').trim();
    final generatedAt =
        DateTime.tryParse(decoded['generated_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final sourceCorpus = (decoded['source_corpus'] as String? ?? '').trim();
    final corpusScamRowCount = _readInt(decoded['corpus_scam_row_count']);
    final updatedAtMs = generatedAt.millisecondsSinceEpoch;

    final parsed = <ScamTemplate>[];
    for (final item in templatesRaw) {
      if (item is! Map<String, dynamic>) {
        onValidationWarning?.call(
          'Skipping malformed seed template entry (not an object).',
        );
        continue;
      }

      final id = (item['id'] as String? ?? '').trim();
      final category = (item['category'] as String? ?? '').trim();
      final pattern = (item['pattern'] as String? ?? '').trim();
      if (id.isEmpty || category.isEmpty || pattern.isEmpty) {
        onValidationWarning?.call(
          'Skipping seed template with missing id/category/pattern.',
        );
        continue;
      }

      parsed.add(
        ScamTemplate(
          id: id,
          category: category,
          language: _languageFromTemplateId(id),
          regexPatterns: <String>[pattern],
          keywordAll: _seedList(item['keyword_all']),
          keywordAnyOf: _seedList(item['keyword_any_of']),
          precision: _readDouble(item['precision']),
          recall: _readDouble(item['recall']),
          exampleMatches: _seedList(item['example_matches']),
          notes: _readNullableString(item['notes']),
          severity: _defaultSeverityForCategory(category),
          reason: _defaultNeutralReason(category),
          enabled: true,
          updatedAtMs: updatedAtMs,
        ),
      );
    }

    return ScamTemplateSeedBundle(
      version: version,
      generatedAt: generatedAt,
      sourceCorpus: sourceCorpus,
      corpusScamRowCount: corpusScamRowCount,
      templates: parsed,
    );
  }

  static List<String> _seedList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _languageFromTemplateId(String id) {
    final firstHyphen = id.indexOf('-');
    if (firstHyphen > 0) {
      final prefix = id.substring(0, firstHyphen).toLowerCase();
      if (prefix.length == 2 || prefix.length == 3) {
        return prefix;
      }
    }
    return 'en';
  }

  static ScamSeverity _defaultSeverityForCategory(String category) {
    switch (category) {
      case 'bank_impersonation':
      case 'kyc_update':
      case 'digital_arrest':
      case 'otp_request':
        return ScamSeverity.alert;
      case 'reward_cashback':
      case 'courier':
      case 'refund':
      case 'utility_bill':
      case 'investment_crypto':
      case 'job_offer':
        return ScamSeverity.warn;
      default:
        return ScamSeverity.info;
    }
  }

  static String _defaultNeutralReason(String category) {
    final topic = switch (category) {
      'bank_impersonation' => 'bank-account requests',
      'kyc_update' => 'KYC update requests',
      'reward_cashback' => 'reward or cashback offers',
      'courier' => 'delivery or courier requests',
      'refund' => 'refund requests',
      'utility_bill' => 'utility bill reminders',
      'investment_crypto' => 'investment offers',
      'digital_arrest' => 'threatening legal claims',
      'otp_request' => 'OTP requests',
      'job_offer' => 'job offers',
      _ => 'this message',
    };
    return 'This looks suspicious for $topic. We\'re not sure, so please check with your caregiver.';
  }
}

class ScamTemplateSeedBundle {
  const ScamTemplateSeedBundle({
    required this.version,
    required this.generatedAt,
    required this.sourceCorpus,
    required this.corpusScamRowCount,
    required this.templates,
  });

  final String version;
  final DateTime generatedAt;
  final String sourceCorpus;
  final int? corpusScamRowCount;
  final List<ScamTemplate> templates;
}
