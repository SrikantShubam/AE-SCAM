import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Guardian app shell boots and shows the root scaffold',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(const ProviderScope(child: GuardianApp()));
      await tester.pumpAndSettle();

      expect(find.text('Guardian'), findsOneWidget);
      expect(find.text('Guided setup in 4 short steps'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    },
  );
}
