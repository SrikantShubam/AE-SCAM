import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:guardian/features/protection/services/diagnostics_gate.dart';
import 'package:guardian/features/protection/services/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnostics gate is disabled by default', () {
    expect(kDiagnosticsEnabled, isFalse);
  });

  test('notification diagnostics log is capped to last 20 entries', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    for (var i = 0; i < 25; i++) {
      await DiagnosticsService.appendNotificationEvent(
        sender: 'sender-$i',
        messageBody: 'message body $i',
        matchResult: i.isEven ? 'matched' : 'unmatched',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('diagnostics_notification_events_v1');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List<dynamic>;
    expect(decoded.length, 20);
  });
}
