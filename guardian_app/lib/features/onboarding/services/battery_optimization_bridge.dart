import 'package:flutter/services.dart';

class BatteryOptimizationBridge {
  BatteryOptimizationBridge._();

  static const MethodChannel _channel = MethodChannel('com.guardian/settings');

  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openBatteryOptimizationSettings',
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
