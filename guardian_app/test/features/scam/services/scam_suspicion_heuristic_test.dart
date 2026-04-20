import 'package:guardian/features/scam/services/scam_suspicion_heuristic.dart';
import 'package:test/test.dart';

void main() {
  group('ScamSuspicionHeuristic', () {
    test('detects has_url and triggers with sender-not-in-contacts rule', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Track here: https://bit.ly/fake-link',
        senderInContacts: false,
      );

      expect(result.matchedSignals, contains('has_url'));
      expect(result.detectedUrls, isNotEmpty);
      expect(result.triggered, isTrue);
    });

    test(
      'does not trigger with single url signal when sender is known contact',
      () {
        final result = ScamSuspicionHeuristic.evaluate(
          text: 'Check this: https://example.com',
          senderInContacts: true,
        );

        expect(result.matchedSignals, contains('has_url'));
        expect(result.triggered, isFalse);
      },
    );

    test('detects has_phone and has_auth_words together', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Call +91 9876543210 for OTP verification.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_phone'));
      expect(result.matchedSignals, contains('has_auth_words'));
      expect(result.triggered, isTrue);
    });

    test('detects has_money using UPI and rupee amount patterns', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Pay Rs 25,000 to john.doe@upi now.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_money'));
    });

    test('detects has_urgency with within-hours phrase', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Act within 2 hours or your account is blocked.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_urgency'));
      expect(result.matchedSignals, contains('has_auth_words'));
      expect(result.triggered, isTrue);
    });

    test('detects has_auth_words for customer care and helpline wording', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Customer care helpline can verify your refund.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_auth_words'));
    });

    test('does not trigger on benign text with no suspicious signals', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Please bring vegetables on your way home.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, isEmpty);
      expect(result.triggered, isFalse);
    });

    test('does not trigger when only has_phone is present', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Please call me at +91 9123456789.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_phone'));
      expect(result.triggered, isFalse);
    });

    test('does not trigger when only has_money is present', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'I paid Rs 5,000 for groceries yesterday.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_money'));
      expect(result.triggered, isFalse);
    });

    test('does not trigger when only has_urgency is present', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Please respond immediately.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_urgency'));
      expect(result.triggered, isFalse);
    });

    test('does not trigger when only has_auth_words is present', () {
      final result = ScamSuspicionHeuristic.evaluate(
        text: 'Customer care can verify your account details.',
        senderInContacts: true,
      );

      expect(result.matchedSignals, contains('has_auth_words'));
      expect(result.triggered, isFalse);
    });
  });
}
