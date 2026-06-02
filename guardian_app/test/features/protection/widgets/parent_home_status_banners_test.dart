import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/protection/models/payment_protection_snapshot.dart';
import 'package:guardian/features/protection/widgets/parent_home_status_banners.dart';

void main() {
  testWidgets(
    'shows accessibility paused banner when health flag is false',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParentHomeStatusBanners(
              snapshot: PaymentProtectionSnapshot(
                state: PaymentProtectionState.inactive,
                serviceEnabled: false,
                accessibilityHealthEnabled: false,
                reasons: <String>[],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Guardian payment protection paused'), findsOneWidget);
      expect(
        find.textContaining('accessibility protection turned off'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows caregiver pause banner when emergency disable is active',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParentHomeStatusBanners(
              snapshot: PaymentProtectionSnapshot(
                state: PaymentProtectionState.inactive,
                serviceEnabled: false,
                accessibilityHealthEnabled: true,
                emergencyDisabled: true,
                reasons: <String>[],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Protection paused by caregiver'), findsOneWidget);
      expect(find.text('Guardian payment protection paused'), findsNothing);
    },
  );

  testWidgets(
    'renders no banners when protection health is normal',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParentHomeStatusBanners(
              snapshot: PaymentProtectionSnapshot(
                state: PaymentProtectionState.monitoring,
                serviceEnabled: true,
                accessibilityHealthEnabled: true,
                reasons: <String>[],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Guardian payment protection paused'), findsNothing);
      expect(find.text('Protection paused by caregiver'), findsNothing);
    },
  );
}
