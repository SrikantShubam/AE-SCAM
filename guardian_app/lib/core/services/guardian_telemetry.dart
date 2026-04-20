import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Narrow, non-PII telemetry helper for WO-OBS-01 Crashlytics events.
class GuardianTelemetry {
  GuardianTelemetry._();

  static void logTemplateFetchFailed({
    required String stage,
    String? errorCode,
  }) {
    _logEvent('template_fetch_failed', <String, String>{
      'stage': _normalizeToken(stage, fallback: 'unknown_stage'),
      if (errorCode != null && errorCode.trim().isNotEmpty)
        'error_code': _normalizeToken(errorCode, fallback: 'unknown_error'),
    });
  }

  static void logFirebaseAuthFailed({
    required String operation,
    String? errorCode,
  }) {
    _logEvent('firebase_auth_failed', <String, String>{
      'operation': _normalizeToken(operation, fallback: 'unknown_operation'),
      if (errorCode != null && errorCode.trim().isNotEmpty)
        'error_code': _normalizeToken(errorCode, fallback: 'unknown_error'),
    });
  }

  static void _logEvent(String eventName, Map<String, String> fields) {
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      final safeEventName = _normalizeToken(eventName, fallback: 'unknown_event');
      crashlytics.setCustomKey('obs_event_name', safeEventName);
      for (final entry in fields.entries) {
        crashlytics.setCustomKey('obs_${entry.key}', entry.value);
      }
      final suffix = fields.entries.map((entry) => '${entry.key}=${entry.value}').join(' ');
      crashlytics.log(
        suffix.isEmpty
            ? 'guardian_obs:$safeEventName'
            : 'guardian_obs:$safeEventName $suffix',
      );
    } catch (_) {
      // Keep telemetry best-effort and non-blocking.
    }
  }

  static String _normalizeToken(String raw, {required String fallback}) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.substring(0, normalized.length > 64 ? 64 : normalized.length);
  }
}
