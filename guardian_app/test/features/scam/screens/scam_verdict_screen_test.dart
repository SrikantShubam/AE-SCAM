import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:guardian/features/scam/screens/scam_verdict_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows verdict details and call caregiver action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    const data = ScamVerdictRouteData(
      sharedText: 'Please update your account statement now.',
      result: ScamMatchResult(
        matched: true,
        templateId: 'en-bank-1',
        category: 'bank_impersonation',
        severity: ScamSeverity.alert,
        reason:
            'This message looks suspicious for bank-account requests. We\'re not sure, so please check with your caregiver.',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ScamVerdictScreen(data: data)),
    );

    expect(find.text('Scam check result'), findsOneWidget);
    expect(find.text('Shared message'), findsOneWidget);
    expect(find.text('Please update your account statement now.'), findsOneWidget);
    expect(find.text('Guardian verdict'), findsOneWidget);
    expect(find.text('Call caregiver'), findsOneWidget);
    expect(find.textContaining('looks suspicious'), findsOneWidget);

    await tester.tap(find.text('Call caregiver'));
    await tester.pump();

    expect(
      find.textContaining('No caregiver phone number is saved yet'),
      findsOneWidget,
    );
  });
}
