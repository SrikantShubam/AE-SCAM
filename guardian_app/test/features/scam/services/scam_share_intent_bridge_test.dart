import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/scam/services/scam_share_intent_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guardian/scam_share_intent');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns normalized pending shared text from native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'consumePendingSharedText') {
            return '  Verify KYC now  ';
          }
          return null;
        });

    final bridge = MethodChannelScamShareIntentBridge(channel: channel);
    final text = await bridge.consumePendingSharedText();

    expect(text, 'Verify KYC now');
  });

  test('invokes callback when native reports shared text is available', () async {
    var callbackCalls = 0;
    final bridge = MethodChannelScamShareIntentBridge(channel: channel);
    bridge.setOnSharedTextAvailable(() async {
      callbackCalls += 1;
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'com.guardian/scam_share_intent',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('sharedTextAvailable'),
          ),
          (_) {},
        );

    expect(callbackCalls, 1);
  });
}
