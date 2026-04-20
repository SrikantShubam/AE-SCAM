import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final consentProvider =
    AsyncNotifierProvider<ConsentNotifier, ConsentRecord>(ConsentNotifier.new);

class ConsentRecord {
  const ConsentRecord({
    required this.consentTimestamp,
    required this.consentVersion,
  });

  final DateTime? consentTimestamp;
  final String? consentVersion;

  bool hasConsentFor(String version) {
    return consentTimestamp != null && consentVersion == version;
  }

  bool get hasAnyConsent =>
      consentTimestamp != null && consentVersion != null;
}

class ConsentNotifier extends AsyncNotifier<ConsentRecord> {
  static const String consentTimestampKey = 'dpdpa_consent_ts';
  static const String consentVersionKey = 'consent_version';

  @override
  FutureOr<ConsentRecord> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return _readRecord(preferences);
  }

  Future<void> recordConsent({
    required String consentVersion,
    DateTime? timestamp,
  }) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final recordedAt = (timestamp ?? DateTime.now()).toUtc();
    await preferences.setString(
      consentTimestampKey,
      recordedAt.toIso8601String(),
    );
    await preferences.setString(consentVersionKey, consentVersion);
    state = AsyncData(
      ConsentRecord(
        consentTimestamp: recordedAt,
        consentVersion: consentVersion,
      ),
    );
  }

  Future<void> clearConsent() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.remove(consentTimestampKey);
    await preferences.remove(consentVersionKey);
    state = const AsyncData(
      ConsentRecord(
        consentTimestamp: null,
        consentVersion: null,
      ),
    );
  }

  ConsentRecord _readRecord(SharedPreferences preferences) {
    final timestampValue = preferences.getString(consentTimestampKey);
    final versionValue = preferences.getString(consentVersionKey);
    return ConsentRecord(
      consentTimestamp: timestampValue == null
          ? null
          : DateTime.tryParse(timestampValue)?.toUtc(),
      consentVersion: versionValue,
    );
  }
}
