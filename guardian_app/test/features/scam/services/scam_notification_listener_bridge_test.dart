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
    'returns parsed notification inputs when payload list is valid',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'consumePendingNotificationPayloadJsonList') {
              return <String>[
                '{"source_package":"com.whatsapp","sender":"BANK-ALERT","message_body":"Verify KYC now","received_at_ms":12345}',
                '{"source_package":"com.android.mms","sender":"","message_body":"OTP is 123456","received_at_ms":98765}',
              ];
            }
            return null;
          });

      final bridge = MethodChannelScamNotificationListenerBridge(
        channel: channel,
      );
      final inputs = await bridge.consumePendingNotificationInputs();

      expect(inputs, hasLength(2));
      expect(inputs.first.sourcePackage, 'com.whatsapp');
      expect(inputs.first.sender, 'BANK-ALERT');
      expect(inputs.first.messageBody, 'Verify KYC now');
      expect(inputs.first.receivedAtMs, 12345);
      expect(inputs.last.sourcePackage, 'com.android.mms');
      expect(inputs.last.sender, isNull);
      expect(inputs.last.messageBody, 'OTP is 123456');
      expect(inputs.last.receivedAtMs, 98765);
    },
  );

  test('falls back to legacy single payload method', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'consumePendingNotificationPayloadJsonList') {
            return null;
          }
          if (call.method == 'consumePendingNotificationPayloadJson') {
            return '{"source_package":"com.whatsapp","sender":"Legacy","message_body":"legacy payload","received_at_ms":"55"}';
          }
          return null;
        });

    final bridge = MethodChannelScamNotificationListenerBridge(
      channel: channel,
    );
    final inputs = await bridge.consumePendingNotificationInputs();

    expect(inputs, hasLength(1));
    expect(inputs.first.sender, 'Legacy');
    expect(inputs.first.receivedAtMs, 55);
  });

  test('invokes availability callback on native signal', () async {
    var called = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return null;
        });

    final bridge = MethodChannelScamNotificationListenerBridge(
      channel: channel,
    );
    bridge.setOnNotificationPayloadAvailable(() async {
      called += 1;
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('notificationPayloadAvailable'),
          ),
          (_) {},
        );

    expect(called, 1);
  });
}
