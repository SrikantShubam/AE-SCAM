import 'package:flutter/services.dart';

abstract class ScamShareIntentBridge {
  Future<String?> consumePendingSharedText();
}

class MethodChannelScamShareIntentBridge implements ScamShareIntentBridge {
  MethodChannelScamShareIntentBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.guardian/scam_share_intent';
  final MethodChannel _channel;

  @override
  Future<String?> consumePendingSharedText() async {
    final value = await _channel.invokeMethod<String>(
      'consumePendingSharedText',
    );
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
