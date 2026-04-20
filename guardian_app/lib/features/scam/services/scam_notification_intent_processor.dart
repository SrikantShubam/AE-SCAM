import '../models/scam_match_result.dart';
import '../models/scam_notification_input.dart';
import '../models/scam_template.dart';
import 'scam_template_matcher.dart';

class ScamNotificationVerdict {
  const ScamNotificationVerdict({required this.input, required this.result});

  final ScamNotificationInput input;
  final ScamMatchResult result;
}

class ScamNotificationIntentProcessor {
  const ScamNotificationIntentProcessor._();

  static ScamNotificationVerdict? evaluate({
    required ScamNotificationInput? input,
    required List<ScamTemplate> templates,
    void Function(String message)? onRegexWarning,
  }) {
    if (input == null) {
      return null;
    }
    final messageBody = input.messageBody.trim();
    if (messageBody.isEmpty) {
      return null;
    }

    final result = ScamTemplateMatcher.matchAgainstTemplates(
      text: messageBody,
      senderId: input.sender,
      templates: templates,
      onRegexWarning: onRegexWarning,
    );
    return ScamNotificationVerdict(input: input, result: result);
  }
}
