import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/scam/services/scam_notification_listener_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.guardian/scam_notification_listener');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'returns parsed notification input when payload is valid json',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'consumePendingNotificationPayloadJson') {
              return '''
{"source_package":"com.whatsapp","sender":"BANK-ALERT","message_body":"Verify KYC now","received_at_ms":12345}
''';
            }
            return null;
          });

      final bridge = MethodChannelScamNotificationListenerBridge(
        channel: channel,
      );
      final input = await bridge.consumePendingNotificationInput();

      expect(input, isNotNull);
      expect(input!.sourcePackage, 'com.whatsapp');
      expect(input.sender, 'BANK-ALERT');
      expect(input.messageBody, 'Verify KYC now');
      expect(input.receivedAtMs, 12345);
    },
  );

  test('returns null when pending payload is absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final bridge = MethodChannelScamNotificationListenerBridge(
      channel: channel,
    );
    final input = await bridge.consumePendingNotificationInput();

    expect(input, isNull);
  });
}
