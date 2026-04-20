import '../models/scam_match_result.dart';
import '../models/scam_template.dart';
import 'scam_template_matcher.dart';

class ScamShareIntentVerdict {
  const ScamShareIntentVerdict({
    required this.sharedText,
    required this.result,
  });

  final String sharedText;
  final ScamMatchResult result;
}

class ScamShareIntentProcessor {
  const ScamShareIntentProcessor._();

  static ScamShareIntentVerdict? evaluate({
    required String? sharedText,
    required List<ScamTemplate> templates,
    void Function(String message)? onRegexWarning,
  }) {
    final normalized = sharedText?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final result = ScamTemplateMatcher.matchAgainstTemplates(
      text: normalized,
      templates: templates,
      onRegexWarning: onRegexWarning,
    );
    return ScamShareIntentVerdict(sharedText: normalized, result: result);
  }
}
