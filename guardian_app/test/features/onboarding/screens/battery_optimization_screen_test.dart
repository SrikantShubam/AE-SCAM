import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/features/onboarding/screens/battery_optimization_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settingsChannel = MethodChannel('com.guardian/settings');
  var openBatterySettingsCalls = 0;

  setUp(() {
    openBatterySettingsCalls = 0;
    SharedPreferences.setMockInitialValues(<String, Object>{});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (call) async {
          if (call.method == 'openBatteryOptimizationSettings') {
            openBatterySettingsCalls += 1;
            return true;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, null);
  });

  GoRouter _buildRouter() {
    return GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, _) => const BatteryOptimizationScreen(),
        ),
        GoRoute(
          path: '/onboarding/first-check',
          builder: (_, _) => const Scaffold(body: Text('FirstCheck')),
        ),
      ],
    );
  }

  testWidgets('shows required battery optimization copy and opens settings', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Step 4 of 5'), findsOneWidget);
    expect(find.text('Keep medicine reminders running'), findsOneWidget);
    expect(
      find.text(
        'Some phones stop reminders to save battery. Allow Guardian to run so we can remind your parent on time.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Open battery optimization settings'));
    await tester.pumpAndSettle();

    expect(openBatterySettingsCalls, 1);
  });

  testWidgets('skip marks skipped state and continues onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('FirstCheck'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('battery_optimization_step_skipped'), isTrue);
    expect(prefs.getBool('battery_optimization_step_completed'), isFalse);
  });

  testWidgets('completed marks completed state and continues onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _buildRouter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I completed this'));
    await tester.pumpAndSettle();

    expect(find.text('FirstCheck'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('battery_optimization_step_completed'), isTrue);
    expect(prefs.getBool('battery_optimization_step_skipped'), isFalse);
  });
}
