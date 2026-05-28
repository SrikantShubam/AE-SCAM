import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app.dart';
import 'package:guardian/core/services/guardian_telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settingsChannel = MethodChannel('com.guardian/settings');
  const shareChannel = MethodChannel('com.guardian/scam_share_intent');
  const notificationChannel = MethodChannel('com.guardian/scam_notification_listener');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GuardianTelemetry.debugEventSink = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(settingsChannel, (call) async {
      if (call.method == 'consumePendingNavigationRoute') {
        return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method == 'consumePendingSharedText') {
        return null;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      if (call.method == 'consumePendingNotificationPayloadJsonList') {
        return <dynamic>[];
      }
      if (call.method == 'consumePendingNotificationPayloadJson') {
        return null;
      }
      return null;
    });
  });

  tearDown(() async {
    GuardianTelemetry.debugEventSink = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(settingsChannel, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(notificationChannel, null);
  });

  testWidgets('logs template_fetch_failed when seed hydration throws', (tester) async {
    final events = <Map<String, Object?>>[];
    GuardianTelemetry.debugEventSink = (eventName, fields) {
      events.add(<String, Object?>{
        'eventName': eventName,
        'fields': fields,
      });
    };

    await tester.pumpWidget(const ProviderScope(child: GuardianApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      events.any((event) {
        final fields = event['fields']! as Map<String, String>;
        return event['eventName'] == 'template_fetch_failed' &&
            fields['stage'] == 'seed_hydration';
      }),
      isTrue,
    );
  });
}
