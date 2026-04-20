import 'package:flutter/services.dart';

import 'models/payment_protection_snapshot.dart';

class PaymentProtectionBridge {
  PaymentProtectionBridge._();

  static const MethodChannel _channel = MethodChannel('com.guardian/settings');

  static Future<void> openAccessibilitySettings() {
    return _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'isAccessibilityServiceEnabled',
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<PaymentProtectionSnapshot> loadSnapshot() async {
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>(
        'getPaymentProtectionSnapshot',
      );
      return PaymentProtectionSnapshot.fromPlatform(payload);
    } on MissingPluginException {
      return PaymentProtectionSnapshot.inactive();
    } on PlatformException {
      return PaymentProtectionSnapshot.inactive();
    }
  }

  static Future<bool> markEscalationHandled(String eventId) async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'markEscalationHandled',
        <String, dynamic>{'eventId': eventId},
      );
      return value ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
