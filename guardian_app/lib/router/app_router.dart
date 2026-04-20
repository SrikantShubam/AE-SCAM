import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dashboard/screens/child_dashboard_screen.dart';
import '../features/medication/screens/medication_list_screen.dart';
import '../features/protection/screens/parent_home_screen.dart';
import '../features/protection/screens/protection_home_screen.dart';
import '../features/scam/screens/scam_verdict_screen.dart';
import '../features/scam/models/scam_match_result.dart';
import '../features/onboarding/screens/accessibility_disclosure_screen.dart';
import '../features/onboarding/screens/caregiver_pairing_screen.dart';
import '../features/onboarding/screens/consent_screen.dart';
import '../features/onboarding/screens/disclosure_screen.dart';
import '../features/onboarding/screens/first_payment_check_screen.dart';
import '../features/onboarding/screens/parent_disclosure_screen.dart';
import '../features/onboarding/screens/parent_pairing_screen.dart';
import '../features/onboarding/screens/role_select_screen.dart';
import '../features/onboarding/screens/welcome_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  redirect: _onboardingRedirect,
  routes: <RouteBase>[
    GoRoute(path: '/', redirect: (context, state) => '/onboarding/welcome'),
    GoRoute(
      path: '/protection',
      builder: (BuildContext context, GoRouterState state) {
        return const ProtectionHomeScreen();
      },
    ),
    GoRoute(
      path: '/disclosure/accessibility',
      builder: (BuildContext context, GoRouterState state) {
        return const AccessibilityDisclosureScreen();
      },
    ),
    GoRoute(
      path: '/home/parent',
      builder: (BuildContext context, GoRouterState state) {
        return const ParentHomeScreen();
      },
    ),
    GoRoute(
      path: '/home/child',
      builder: (BuildContext context, GoRouterState state) {
        return const ChildDashboardScreen();
      },
    ),
    GoRoute(
      path: '/medications/setup',
      builder: (BuildContext context, GoRouterState state) {
        return const MedicationListScreen();
      },
    ),
    GoRoute(
      path: '/scam/verdict',
      builder: (BuildContext context, GoRouterState state) {
        final extra = state.extra;
        final data = extra is ScamVerdictRouteData
            ? extra
            : ScamVerdictRouteData(
                sharedText: '',
                result: const ScamMatchResult(
                  matched: false,
                  templateId: null,
                  category: null,
                  severity: ScamSeverity.info,
                  reason:
                      "This message looks suspicious. We're not sure, so please check with your caregiver.",
                ),
              );
        return ScamVerdictScreen(data: data);
      },
    ),
    // Onboarding routes
    GoRoute(
      path: '/onboarding/welcome',
      builder: (BuildContext context, GoRouterState state) {
        return const WelcomeScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/consent',
      builder: (BuildContext context, GoRouterState state) {
        return const ConsentScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/role-select',
      builder: (BuildContext context, GoRouterState state) {
        return const RoleSelectScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/pairing/generate',
      builder: (BuildContext context, GoRouterState state) {
        return CaregiverPairingScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/pairing/enter',
      builder: (BuildContext context, GoRouterState state) {
        return ParentPairingScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/disclosure',
      builder: (BuildContext context, GoRouterState state) {
        return const DisclosureScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/parent-disclosure',
      builder: (BuildContext context, GoRouterState state) {
        return const ParentDisclosureScreen();
      },
    ),
    GoRoute(
      path: '/onboarding/first-check',
      builder: (BuildContext context, GoRouterState state) {
        return const FirstPaymentCheckScreen();
      },
    ),
  ],
);

FutureOr<String?> _onboardingRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
  final paymentProtectionSetupComplete =
      prefs.getBool('payment_protection_setup_complete') ?? false;
  final userRole = prefs.getString('user_role');
  final location = state.matchedLocation;
  final isOnboardingRoute = location.startsWith('/onboarding');
  final isScamVerdictRoute = location == '/scam/verdict';
  // The standalone Accessibility disclosure must be reachable at any time
  // (Play policy requires a re-enterable disclosure surface), including
  // before onboarding is complete so reviewers can deep-link to it.
  final isStandaloneDisclosure = location == '/disclosure/accessibility';

  // If onboarding not complete, route through onboarding flow
  if (!onboardingComplete &&
      !isOnboardingRoute &&
      !isStandaloneDisclosure &&
      !isScamVerdictRoute) {
    return '/onboarding/welcome';
  }

  // Existing installs may already have onboarding_complete from earlier builds.
  // Keep them inside the new payment-protection setup flow until that setup is
  // explicitly completed once.
  if (onboardingComplete &&
      !paymentProtectionSetupComplete &&
      !isOnboardingRoute &&
      !isScamVerdictRoute) {
    if (userRole == 'parent') {
      return '/onboarding/parent-disclosure';
    }
    if (userRole == 'child') {
      return '/onboarding/disclosure';
    }
    return '/onboarding/role-select';
  }

  // If onboarding complete, route to role-specific home
  if (onboardingComplete && isOnboardingRoute) {
    if (!paymentProtectionSetupComplete) {
      final protectedSetupRoutes = <String>{
        '/onboarding/role-select',
        '/onboarding/disclosure',
        '/onboarding/parent-disclosure',
        '/onboarding/first-check',
      };
      if (!protectedSetupRoutes.contains(location)) {
        if (userRole == 'parent') {
          return '/onboarding/parent-disclosure';
        } else if (userRole == 'child') {
          return '/onboarding/disclosure';
        }
        return '/onboarding/role-select';
      }
      return null;
    }

    if (userRole == 'parent') {
      return '/home/parent';
    } else if (userRole == 'child') {
      return '/home/child';
    }
    return '/onboarding/role-select';
  }

  return null;
}
