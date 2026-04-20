import 'scam_parent_warning_notifier.dart';

class ScamConfirmedThreatHandler {
  ScamConfirmedThreatHandler({required ScamParentWarningNotifier notifier})
    : _notifier = notifier;

  final ScamParentWarningNotifier _notifier;

  Future<bool> handle({
    required bool confirmedThreat,
    required String messageBody,
  }) async {
    if (!confirmedThreat) {
      return false;
    }
    await _notifier.showConfirmedThreatWarning(messageBody: messageBody);
    return true;
  }
}
