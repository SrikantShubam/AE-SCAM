import '../models/scam_match_result.dart';
import '../models/scam_template.dart';

typedef ScamTemplateLoader =
    Future<List<ScamTemplate>> Function(String language);

class ScamTemplateMatcher {
  ScamTemplateMatcher({
    required ScamTemplateLoader templateLoader,
    void Function(String message)? onRegexWarning,
  }) : _templateLoader = templateLoader,
       _onRegexWarning = onRegexWarning;

  final ScamTemplateLoader _templateLoader;
  final void Function(String message)? _onRegexWarning;

  Future<ScamMatchResult> match({
    required String text,
    String? senderId,
    required String language,
  }) async {
    final templates = await _templateLoader(language);
    return matchAgainstTemplates(
      text: text,
      senderId: senderId,
      templates: templates,
      onRegexWarning: _onRegexWarning,
    );
  }

  static ScamMatchResult matchAgainstTemplates({
    required String text,
    String? senderId,
    required List<ScamTemplate> templates,
    void Function(String message)? onRegexWarning,
  }) {
    final hasSenderId = senderId != null && senderId.trim().isNotEmpty;
    final input = text.trim();
    if (input.isEmpty || templates.isEmpty) {
      return ScamMatchResult.unmatched();
    }

    final normalizedText = input.toLowerCase();
    final regexMatch = _matchByRegex(
      templates,
      input,
      onRegexWarning: onRegexWarning,
    );
    if (regexMatch != null) {
      return _toResult(regexMatch);
    }

    final keywordMatch = _matchByKeywords(templates, normalizedText);
    if (keywordMatch != null) {
      return _toResult(keywordMatch);
    }

    if (hasSenderId) {
      return ScamMatchResult.unmatched();
    }
    return ScamMatchResult.unmatched();
  }

  static ScamTemplate? _matchByRegex(
    List<ScamTemplate> templates,
    String input, {
    void Function(String message)? onRegexWarning,
  }) {
    for (final template in templates) {
      for (final pattern in template.regexPatterns) {
        if (pattern.trim().isEmpty) {
          continue;
        }
        RegExp regExp;
        try {
          regExp = RegExp(
            pattern,
            caseSensitive: false,
            dotAll: true,
            multiLine: true,
          );
        } on FormatException {
          onRegexWarning?.call(
            'Skipping invalid scam regex pattern for ${template.id}.',
          );
          continue;
        }
        if (regExp.hasMatch(input)) {
          return template;
        }
      }
    }
    return null;
  }

  static ScamTemplate? _matchByKeywords(
    List<ScamTemplate> templates,
    String normalizedText,
  ) {
    for (final template in templates) {
      if (!_containsAll(normalizedText, template.keywordAll)) {
        continue;
      }
      if (template.keywordAnyOf.isNotEmpty &&
          !_containsAny(normalizedText, template.keywordAnyOf)) {
        continue;
      }
      return template;
    }
    return null;
  }

  static bool _containsAll(String normalizedText, List<String> terms) {
    if (terms.isEmpty) {
      return false;
    }
    for (final term in terms) {
      final candidate = term.trim().toLowerCase();
      if (candidate.isEmpty) {
        continue;
      }
      if (!normalizedText.contains(candidate)) {
        return false;
      }
    }
    return true;
  }

  static bool _containsAny(String normalizedText, List<String> terms) {
    for (final term in terms) {
      final candidate = term.trim().toLowerCase();
      if (candidate.isEmpty) {
        continue;
      }
      if (normalizedText.contains(candidate)) {
        return true;
      }
    }
    return false;
  }

  static ScamMatchResult _toResult(ScamTemplate template) {
    return ScamMatchResult(
      matched: true,
      templateId: template.id,
      category: template.category,
      severity: template.severity,
      reason: template.reason,
    );
  }
}
