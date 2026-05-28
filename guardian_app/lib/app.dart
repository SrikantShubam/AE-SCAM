import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services/local_db.dart';
import 'core/services/guardian_telemetry.dart';
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
import 'features/scam/widgets/scam_language_scope_notice_host.dart';
import 'features/protection/payment_protection_bridge.dart';
import 'features/protection/services/diagnostics_service.dart';
import 'features/protection/services/emergency_disable_sync_service.dart';
import 'features/medication/services/medication_alarm_ack_sync_service.dart';
import 'features/medication/services/medication_alarm_platform_bridge.dart';
import 'features/medication/services/medication_repository.dart';
import 'router/app_router.dart';

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> with WidgetsBindingObserver {
  static const String _scamSeedAssetPath = 'assets/scam_templates/seed_en.json';
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
  final EmergencyDisableSyncService _emergencyDisableSyncService =
      EmergencyDisableSyncService();
  late final MedicationAlarmAckSyncService _medicationAlarmAckSyncService =
      MedicationAlarmAckSyncService(
        bridge: MedicationAlarmPlatformBridge(),
        repository: MedicationRepository(localDb: LocalDb.instance),
      );
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isHandlingShareIntent = false;
  bool _seedTemplatesHydrated = false;

  @override
  void initState() {
    super.initState();
    _shareIntentBridge.setOnSharedTextAvailable(_checkSharedIntentAndRoute);
    _notificationListenerBridge.setOnNotificationPayloadAvailable(
      _checkSharedIntentAndRoute,
    );
    WidgetsBinding.instance.addObserver(this);
    _emergencyDisableSyncService.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingMedicationAlarmAcknowledgements();
      _checkSharedIntentAndRoute();
    });
  }

  @override
  void dispose() {
    _shareIntentBridge.setOnSharedTextAvailable(null);
    _notificationListenerBridge.setOnNotificationPayloadAvailable(null);
    WidgetsBinding.instance.removeObserver(this);
    _emergencyDisableSyncService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPendingMedicationAlarmAcknowledgements();
      _checkSharedIntentAndRoute();
    }
  }

  Future<void> _syncPendingMedicationAlarmAcknowledgements() async {
    try {
      await _medicationAlarmAckSyncService.syncPendingAcknowledgements();
    } catch (_) {
      // Keep alarm acknowledgement sync best-effort.
    }
  }

  Future<void> _checkSharedIntentAndRoute() async {
    if (_isHandlingShareIntent) {
      return;
    }
    _isHandlingShareIntent = true;
    try {
      if (await _emergencyDisableSyncService.isEmergencyDisabled()) {
        return;
      }
      final localeTag = _currentLocaleTag();

      final route = await PaymentProtectionBridge.consumePendingNavigationRoute();
      if (route != null && mounted) {
        appRouter.go(route);
      }

      await _ensureSeedTemplatesHydrated();
      final sharedText = await _shareIntentBridge.consumePendingSharedText();
      if (sharedText == null) {
        final notificationInputs = await _notificationListenerBridge
            .consumePendingNotificationInputs();
        if (notificationInputs.isEmpty) {
          return;
        }
        for (final notificationInput in notificationInputs) {
          final templates = await _templateRepository
              .listEnabledTemplatesByLanguage(localeTag);
          final notificationVerdict = ScamNotificationIntentProcessor.evaluate(
            input: notificationInput,
            templates: templates,
          );
          if (notificationVerdict == null) {
            continue;
          }
          await DiagnosticsService.appendNotificationEvent(
            sender: notificationVerdict.input.sender,
            messageBody: notificationVerdict.input.messageBody,
            matchResult: notificationVerdict.result.matched
                ? 'matched'
                : 'unmatched',
          );
          if (notificationVerdict.result.matched) {
            if (!mounted) {
              return;
            }
            appRouter.push(
              '/scam/verdict',
              extra: ScamVerdictRouteData(
                sharedText: notificationVerdict.input.messageBody,
                result: notificationVerdict.result,
              ),
            );
            continue;
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
        }
        return;
      }

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

  Future<void> _ensureSeedTemplatesHydrated() async {
    if (_seedTemplatesHydrated) {
      return;
    }
    try {
      final existing = await _templateRepository.listEnabledTemplatesByLanguage(
        'en',
      );
      if (existing.isNotEmpty) {
        _seedTemplatesHydrated = true;
        return;
      }

      final seedBundleJson = await rootBundle.loadString(_scamSeedAssetPath);
      await _templateRepository.upsertSeedBundleJson(seedBundleJson);
      _seedTemplatesHydrated = true;
    } catch (_) {
      GuardianTelemetry.logTemplateFetchFailed(stage: 'seed_hydration');
      rethrow;
    }
  }

  String _currentLocaleTag() {
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    if (locales.isNotEmpty) {
      return locales.first.toLanguageTag();
    }
    return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
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
      scaffoldMessengerKey: _scaffoldMessengerKey,
      builder: (context, child) => ScamLanguageScopeNoticeHost(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
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
