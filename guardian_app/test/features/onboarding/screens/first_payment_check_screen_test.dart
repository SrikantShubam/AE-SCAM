import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/onboarding/screens/first_payment_check_screen.dart';

void main() {
  testWidgets('shows inexact reminder timing copy for medication setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FirstPaymentCheckScreen()),
    );

    expect(
      find.text(
        'Reminders may be up to 15 minutes late on some phones to save battery.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('exact alarms should be allowed'), findsNothing);
  });
}
