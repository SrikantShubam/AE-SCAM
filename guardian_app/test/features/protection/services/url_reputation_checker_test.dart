import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/protection/services/url_reputation_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guardian/url_reputation');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns unknown for blank url', () async {
    const checker = UrlReputationChecker(channel: channel);
    final verdict = await checker.check('  ');
    expect(verdict, ThreatVerdict.unknown);
  });

  test('maps platform verdict values', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch ((call.arguments as Map)['url'] as String) {
            'https://safe.test' => 'safe',
            'https://phish.test' => 'phishing',
            'https://malware.test' => 'malware',
            _ => 'unwanted',
          };
        });
    const checker = UrlReputationChecker(channel: channel);

    expect(await checker.check('https://safe.test'), ThreatVerdict.safe);
    expect(await checker.check('https://phish.test'), ThreatVerdict.phishing);
    expect(await checker.check('https://malware.test'), ThreatVerdict.malware);
    expect(await checker.check('https://other.test'), ThreatVerdict.unwanted);
  });

  test('falls back to unknown on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'err');
        });
    const checker = UrlReputationChecker(channel: channel);

    expect(await checker.check('https://example.com'), ThreatVerdict.unknown);
  });
}
