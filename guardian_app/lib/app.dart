import 'package:flutter/material.dart';

import 'core/services/local_db.dart';
import 'features/scam/models/scam_match_result.dart';
import 'features/scam/screens/scam_verdict_screen.dart';
import 'features/scam/services/scam_candidate_repository.dart';
import 'features/scam/services/scam_confirmed_threat_handler.dart';
import 'features/scam/services/scam_notification_intent_processor.dart';
import 'features/scam/services/scam_notification_listener_bridge.dart';
import 'features/scam/services/scam_parent_warning_local_notifier.dart';
import 'features/scam/services/scam_share_intent_bridge.dart';
import 'features/scam/services/scam_share_intent_processor.dart';
import 'features/scam/services/scam_template_repository.dart';
import 'router/app_router.dart';

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> with WidgetsBindingObserver {
  final ScamShareIntentBridge _shareIntentBridge =
      MethodChannelScamShareIntentBridge();
  final ScamNotificationListenerBridge _notificationListenerBridge =
      MethodChannelScamNotificationListenerBridge();
  final ScamTemplateRepository _templateRepository = ScamTemplateRepository(
    localDb: LocalDb.instance,
  );
  final ScamCandidateRepository _scamCandidateRepository =
      ScamCandidateRepository(localDb: LocalDb.instance);
  late final ScamConfirmedThreatHandler _confirmedThreatHandler =
      ScamConfirmedThreatHandler(notifier: LocalScamParentWarningNotifier());

  bool _isHandlingShareIntent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSharedIntentAndRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSharedIntentAndRoute();
    }
  }

  Future<void> _checkSharedIntentAndRoute() async {
    if (_isHandlingShareIntent) {
      return;
    }
    _isHandlingShareIntent = true;
    try {
      final sharedText = await _shareIntentBridge.consumePendingSharedText();
      if (sharedText == null) {
        final notificationInput = await _notificationListenerBridge
            .consumePendingNotificationInput();
        if (notificationInput == null) {
          return;
        }
        final localeTag = WidgetsBinding.instance.platformDispatcher.locale
            .toLanguageTag();
        final templates = await _templateRepository
            .listEnabledTemplatesByLanguage(localeTag);
        final notificationVerdict = ScamNotificationIntentProcessor.evaluate(
          input: notificationInput,
          templates: templates,
        );
        if (notificationVerdict == null || notificationVerdict.result.matched) {
          return;
        }
        final queueResult = await _scamCandidateRepository
            .evaluateAndQueueIfSuspicious(
          text: notificationVerdict.input.messageBody,
          sender: notificationVerdict.input.sender,
          source: 'notification_listener',
        );
        final handled = await _confirmedThreatHandler.handle(
          confirmedThreat: queueResult.confirmedThreat,
          messageBody: notificationVerdict.input.messageBody,
        );
        if (handled) {
          if (!mounted) {
            return;
          }
          appRouter.push(
            '/scam/verdict',
            extra: ScamVerdictRouteData(
              sharedText: notificationVerdict.input.messageBody,
              result: ScamMatchResult.confirmedUrlThreat(),
            ),
          );
        }
        return;
      }

      final localeTag = WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag();
      final templates = await _templateRepository
          .listEnabledTemplatesByLanguage(localeTag);
      final verdict = ScamShareIntentProcessor.evaluate(
        sharedText: sharedText,
        templates: templates,
      );
      if (verdict == null || !mounted) {
        return;
      }
      if (!verdict.result.matched) {
        final queueResult = await _scamCandidateRepository
            .evaluateAndQueueIfSuspicious(
          text: verdict.sharedText,
          sender: null,
          source: 'share_intent',
        );
        final handled = await _confirmedThreatHandler.handle(
          confirmedThreat: queueResult.confirmedThreat,
          messageBody: verdict.sharedText,
        );
        if (handled) {
          if (!mounted) {
            return;
          }
          appRouter.push(
            '/scam/verdict',
            extra: ScamVerdictRouteData(
              sharedText: verdict.sharedText,
              result: ScamMatchResult.confirmedUrlThreat(),
            ),
          );
          return;
        }
        if (!mounted) {
          return;
        }
      }

      appRouter.push(
        '/scam/verdict',
        extra: ScamVerdictRouteData(
          sharedText: verdict.sharedText,
          result: verdict.result,
        ),
      );
    } catch (_) {
      // Share-intent checks are best-effort and should never block app startup.
    } finally {
      _isHandlingShareIntent = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF156B7A),
      brightness: Brightness.light,
    );

    final textTheme = ThemeData.light().textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      bodyLarge: const TextStyle(fontSize: 18, height: 1.45),
      bodyMedium: const TextStyle(fontSize: 18, height: 1.45),
    );

    return MaterialApp.router(
      title: 'Guardian',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7FAFB),
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}
