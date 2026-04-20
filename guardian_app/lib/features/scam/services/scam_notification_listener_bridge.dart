import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/scam_notification_input.dart';

abstract class ScamNotificationListenerBridge {
  Future<ScamNotificationInput?> consumePendingNotificationInput();
}

class MethodChannelScamNotificationListenerBridge
    implements ScamNotificationListenerBridge {
  MethodChannelScamNotificationListenerBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.guardian/scam_notification_listener';
  final MethodChannel _channel;

  @override
  Future<ScamNotificationInput?> consumePendingNotificationInput() async {
    final payloadJson = await _channel.invokeMethod<String>(
      'consumePendingNotificationPayloadJson',
    );
    if (payloadJson == null || payloadJson.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final sourcePackage = (decoded['source_package'] as String? ?? '').trim();
    final messageBody = (decoded['message_body'] as String? ?? '').trim();
    final senderRaw = (decoded['sender'] as String? ?? '').trim();
    final receivedAtMs = _readInt(decoded['received_at_ms']) ?? 0;

    if (sourcePackage.isEmpty || messageBody.isEmpty) {
      return null;
    }

    return ScamNotificationInput(
      sourcePackage: sourcePackage,
      sender: senderRaw.isEmpty ? null : senderRaw,
      messageBody: messageBody,
      receivedAtMs: receivedAtMs,
    );
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
