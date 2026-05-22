import 'package:flutter/services.dart';

enum ThreatVerdict { unknown, safe, phishing, malware, unwanted }

class UrlReputationChecker {
  const UrlReputationChecker({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.guardian/url_reputation';
  final MethodChannel _channel;

  Future<ThreatVerdict> check(String url) async {
    if (url.trim().isEmpty) {
      return ThreatVerdict.unknown;
    }
    try {
      final raw = await _channel.invokeMethod<String>('checkUrlThreat', <String, Object>{
        'url': url,
      });
      return _fromPlatform(raw);
    } on MissingPluginException {
      return ThreatVerdict.unknown;
    } on PlatformException {
      return ThreatVerdict.unknown;
    }
  }

  ThreatVerdict _fromPlatform(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'safe' => ThreatVerdict.safe,
      'phishing' => ThreatVerdict.phishing,
      'malware' => ThreatVerdict.malware,
      'unwanted' => ThreatVerdict.unwanted,
      _ => ThreatVerdict.unknown,
    };
  }
}
