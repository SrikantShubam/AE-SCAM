import 'package:guardian/features/scam/models/scam_candidate.dart';
import 'package:test/test.dart';

void main() {
  group('ScamCandidate.toRemoteMap', () {
    final candidate = ScamCandidate(
      id: 'candidate-1',
      source: 'share_intent',
      textHash: 'abc123hash',
      text: 'Urgent link http://bit.ly/fake',
      sender: 'Unknown',
      signalsMatched: const <String>['has_url', 'has_urgency'],
      urlVerdicts: const <String>['http://bit.ly/fake:unknown'],
      createdAtMs: 1712345678901,
      status: 'pending_review',
    );

    test('uses text_hash key and does not emit legacy message_hash key', () {
      final map = candidate.toRemoteMap(includeSensitiveText: true);

      expect(map['text_hash'], 'abc123hash');
      expect(map.containsKey('message_hash'), isFalse);
    });

    test('redacts sensitive fields when includeSensitiveText is false', () {
      final map = candidate.toRemoteMap(includeSensitiveText: false);

      expect(map['text'], isNull);
      expect(map['sender'], isNull);
      expect(map['message_preview'], isNull);
    });
  });
}
