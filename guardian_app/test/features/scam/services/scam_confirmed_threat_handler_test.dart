import 'package:guardian/features/scam/services/scam_confirmed_threat_handler.dart';
import 'package:guardian/features/scam/services/scam_parent_warning_notifier.dart';
import 'package:test/test.dart';

class _FakeScamParentWarningNotifier implements ScamParentWarningNotifier {
  int calls = 0;
  String? lastMessageBody;

  @override
  Future<void> showConfirmedThreatWarning({required String messageBody}) async {
    calls += 1;
    lastMessageBody = messageBody;
  }
}

void main() {
  group('ScamConfirmedThreatHandler', () {
    test('posts immediate warning and returns true for confirmedThreat', () async {
      final notifier = _FakeScamParentWarningNotifier();
      final handler = ScamConfirmedThreatHandler(notifier: notifier);

      final handled = await handler.handle(
        confirmedThreat: true,
        messageBody: 'Click http://malicious.test now',
      );

      expect(handled, isTrue);
      expect(notifier.calls, 1);
      expect(notifier.lastMessageBody, 'Click http://malicious.test now');
    });

    test('does nothing and returns false when threat is not confirmed', () async {
      final notifier = _FakeScamParentWarningNotifier();
      final handler = ScamConfirmedThreatHandler(notifier: notifier);

      final handled = await handler.handle(
        confirmedThreat: false,
        messageBody: 'Track shipment here',
      );

      expect(handled, isFalse);
      expect(notifier.calls, 0);
    });
  });
}
