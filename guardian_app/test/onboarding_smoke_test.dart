import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/features/onboarding/screens/consent_screen.dart';
import 'package:guardian/features/onboarding/screens/disclosure_screen.dart';
import 'package:guardian/features/onboarding/screens/parent_disclosure_screen.dart';
import 'package:guardian/features/onboarding/screens/role_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guardianChannel = MethodChannel('com.guardian/settings');
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  String? launchedUrl;

  setUp(() {
    launchedUrl = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guardianChannel, (call) async {
          if (call.method == 'isAccessibilityServiceEnabled') {
            return false;
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          if (call.method == 'launch' || call.method == 'launchUrl') {
            final arguments = call.arguments;
            if (arguments is String) {
              launchedUrl = arguments;
            } else if (arguments is Map) {
              launchedUrl =
                  arguments['url'] as String? ?? arguments['uri'] as String?;
            }
            return true;
          }
          if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
            return true;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guardianChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
  });

  testWidgets(
    'disclosure screen shows the minimal child disclosure and hides check again initially',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: DisclosureScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(find.text('Enable live payment protection'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Open Android Accessibility settings'),
        200,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Open Android Accessibility settings'), findsOneWidget);
      expect(find.text('Check again'), findsNothing);
      expect(
        find.text(
          'Accessibility permission lets Guardian read the payment screen on the parent\'s device before money is sent. It reads the amount, recipient, and UPI ID - nothing else.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('See exactly what Guardian can and cannot see →'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'parent disclosure screen shows the minimal parent disclosure and hides check again initially',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ParentDisclosureScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Step 3 of 4'), findsOneWidget);
      expect(
        find.text('Guardian needs one permission'),
        findsAtLeastNWidgets(1),
      );
      await tester.scrollUntilVisible(
        find.text('Open Android Accessibility settings'),
        200,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Open Android Accessibility settings'), findsOneWidget);
      expect(find.text('Check again'), findsNothing);
      expect(
        find.text('See exactly what Guardian can and cannot see →'),
        findsOneWidget,
      );
      expect(find.text('Skip for now'), findsOneWidget);
    },
  );

  testWidgets('consent screen shows the current consent summary', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ConsentScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('A few things before we start'), findsOneWidget);
    expect(find.text('Read the full privacy policy'), findsOneWidget);
  });

  testWidgets('consent screen opens the live privacy policy link', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ConsentScreen())),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Read the full privacy policy'),
      200,
    );
    await tester.pump();
    await tester.tap(find.text('Read the full privacy policy'));
    await tester.pump();

    expect(launchedUrl, 'https://vectorveda.online/guardian-privacy-policy');
    expect(
      find.text('Privacy policy link will be connected in a later phase.'),
      findsNothing,
    );
  });

  testWidgets('role-select screen shows the device-role choices', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Whose phone is this?'), findsOneWidget);
    expect(find.text('The parent\'s phone'), findsOneWidget);
    expect(find.text('The child or caregiver phone'), findsOneWidget);
  });

  testWidgets('role-select child flow routes to caregiver pairing screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const RoleSelectScreen()),
        GoRoute(
          path: '/onboarding/pairing/generate',
          builder: (_, _) => const Scaffold(body: Text('GeneratePairing')),
        ),
        GoRoute(
          path: '/onboarding/pairing/enter',
          builder: (_, _) => const Scaffold(body: Text('EnterPairing')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('The child or caregiver phone'));
    await tester.pumpAndSettle();

    expect(find.text('GeneratePairing'), findsOneWidget);
  });

  testWidgets('role-select parent flow routes to parent pairing screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const RoleSelectScreen()),
        GoRoute(
          path: '/onboarding/pairing/generate',
          builder: (_, _) => const Scaffold(body: Text('GeneratePairing')),
        ),
        GoRoute(
          path: '/onboarding/pairing/enter',
          builder: (_, _) => const Scaffold(body: Text('EnterPairing')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text("The parent's phone"));
    await tester.pumpAndSettle();

    expect(find.text('EnterPairing'), findsOneWidget);
  });
}
