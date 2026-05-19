import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/features/scam/widgets/scam_language_scope_notice_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows non-english scam notice only once', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final messengerKey = GlobalKey<ScaffoldMessengerState>();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi', 'IN'),
        supportedLocales: const <Locale>[Locale('en'), Locale('hi', 'IN')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        scaffoldMessengerKey: messengerKey,
        home: Scaffold(
          body: ScamLanguageScopeNoticeHost(
            scaffoldMessengerKey: messengerKey,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Guardian scam detection currently supports English only.'),
      findsOneWidget,
    );

    final prefsAfterFirstShow = await SharedPreferences.getInstance();
    expect(
      prefsAfterFirstShow.getBool('guardian_scam_english_only_notice_shown'),
      isTrue,
    );
    messengerKey.currentState?.clearSnackBars();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi', 'IN'),
        supportedLocales: const <Locale>[Locale('en'), Locale('hi', 'IN')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        scaffoldMessengerKey: messengerKey,
        home: Scaffold(
          body: ScamLanguageScopeNoticeHost(
            scaffoldMessengerKey: messengerKey,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Guardian scam detection currently supports English only.'),
      findsNothing,
    );
  });
}
