import 'package:flutter/services.dart';

abstract class ScamShareIntentBridge {
  Future<String?> consumePendingSharedText();

  void setOnSharedTextAvailable(Future<void> Function()? onAvailable);
}

class MethodChannelScamShareIntentBridge implements ScamShareIntentBridge {
  MethodChannelScamShareIntentBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.guardian/scam_share_intent';
  final MethodChannel _channel;

  @override
  void setOnSharedTextAvailable(Future<void> Function()? onAvailable) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedTextAvailable') {
        await onAvailable?.call();
      }
    });
  }

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
