import 'package:flutter/foundation.dart';

enum PaymentProtectionState {
  inactive,
  monitoring,
  amber,
  red,
}

@immutable
class PaymentProtectionSnapshot {
  const PaymentProtectionSnapshot({
    required this.state,
    required this.serviceEnabled,
    required this.reasons,
    this.lastMonitoredPackageName,
    this.lastMonitoredAppLabel,
    this.lastMonitoredAt,
    this.warningWindowSeconds = 60,
    this.paymentContextDetected = false,
    this.matchedSignals = const <String>[],
    this.detectedAmountHint,
    this.detectedRecipientHint,
    this.detectedUpiIdHint,
    this.reviewTitle,
    this.reviewBody,
    this.cooldownSeconds = 0,
    this.proceedLabel,
    this.safeExitLabel,
    this.hasHighAmount = false,
    this.hasSuspiciousLanguage = false,
    this.recipientRecentlyChanged = false,
    this.recipientKnown = false,
    this.escalationRecommended = false,
    this.escalationReason,
    this.lastEscalationEventId,
    this.lastEscalationAt,
    this.lastEscalationAppLabel,
    this.lastEscalationTitle,
    this.lastEscalationBody,
    this.lastEscalationAmountHint,
    this.lastEscalationRecipientHint,
    this.lastEscalationUpiIdHint,
    this.lastEscalationPending = false,
  });

  final PaymentProtectionState state;
  final bool serviceEnabled;
  final List<String> reasons;
  final String? lastMonitoredPackageName;
  final String? lastMonitoredAppLabel;
  final DateTime? lastMonitoredAt;
  final int warningWindowSeconds;
  final bool paymentContextDetected;
  final List<String> matchedSignals;
  final String? detectedAmountHint;
  final String? detectedRecipientHint;
  final String? detectedUpiIdHint;
  final String? reviewTitle;
  final String? reviewBody;
  final int cooldownSeconds;
  final String? proceedLabel;
  final String? safeExitLabel;
  final bool hasHighAmount;
  final bool hasSuspiciousLanguage;
  final bool recipientRecentlyChanged;
  final bool recipientKnown;
  final bool escalationRecommended;
  final String? escalationReason;
  final String? lastEscalationEventId;
  final DateTime? lastEscalationAt;
  final String? lastEscalationAppLabel;
  final String? lastEscalationTitle;
  final String? lastEscalationBody;
  final String? lastEscalationAmountHint;
  final String? lastEscalationRecipientHint;
  final String? lastEscalationUpiIdHint;
  final bool lastEscalationPending;

  bool get isInactive => state == PaymentProtectionState.inactive;
  bool get isMonitoring => state == PaymentProtectionState.monitoring;
  bool get isAmber => state == PaymentProtectionState.amber;
  bool get isRed => state == PaymentProtectionState.red;
  bool get isWarning => isAmber || isRed;
  bool get hasElevatedRiskSignals =>
      hasHighAmount ||
      hasSuspiciousLanguage ||
      recipientRecentlyChanged ||
      escalationRecommended ||
      (!recipientKnown &&
          (detectedRecipientHint != null || detectedUpiIdHint != null));

  bool get isRecipientKnown => recipientKnown;

  bool get isNewRecipient =>
      !recipientKnown &&
      (detectedRecipientHint != null || detectedUpiIdHint != null);

  factory PaymentProtectionSnapshot.inactive() {
    return const PaymentProtectionSnapshot(
      state: PaymentProtectionState.inactive,
      serviceEnabled: false,
      reasons: <String>['Live payment protection is off.'],
    );
  }

  factory PaymentProtectionSnapshot.fromPlatform(
    Map<String, dynamic>? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return PaymentProtectionSnapshot.inactive();
    }

    final lastSeenAtMs = (raw['lastMonitoredAtMs'] as num?)?.toInt();
    final lastEscalationAtMs = (raw['lastEscalationAtMs'] as num?)?.toInt();
    final warningWindowMs = (raw['warningWindowMs'] as num?)?.toInt();

    return PaymentProtectionSnapshot(
      state: _parseState(raw['state'] as String?),
      serviceEnabled: raw['serviceEnabled'] as bool? ?? false,
      reasons: (raw['reasons'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          <String>[],
      lastMonitoredPackageName: raw['lastMonitoredPackageName'] as String?,
      lastMonitoredAppLabel: raw['lastMonitoredAppLabel'] as String?,
      lastMonitoredAt: lastSeenAtMs == null || lastSeenAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSeenAtMs).toLocal(),
      warningWindowSeconds:
          warningWindowMs == null ? 60 : (warningWindowMs ~/ 1000),
      paymentContextDetected: raw['paymentContextDetected'] as bool? ?? false,
      matchedSignals: (raw['matchedSignals'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          <String>[],
      detectedAmountHint: raw['detectedAmountHint'] as String?,
      detectedRecipientHint: raw['detectedRecipientHint'] as String?,
      detectedUpiIdHint: raw['detectedUpiIdHint'] as String?,
      reviewTitle: raw['reviewTitle'] as String?,
      reviewBody: raw['reviewBody'] as String?,
      cooldownSeconds: (raw['cooldownSeconds'] as num?)?.toInt() ?? 0,
      proceedLabel: raw['proceedLabel'] as String?,
      safeExitLabel: raw['safeExitLabel'] as String?,
      hasHighAmount: raw['hasHighAmount'] as bool? ?? false,
      hasSuspiciousLanguage: raw['hasSuspiciousLanguage'] as bool? ?? false,
      recipientRecentlyChanged:
          raw['recipientRecentlyChanged'] as bool? ?? false,
      recipientKnown: raw['recipientKnown'] as bool? ?? false,
      escalationRecommended:
          raw['escalationRecommended'] as bool? ?? false,
      escalationReason: raw['escalationReason'] as String?,
      lastEscalationEventId: raw['lastEscalationEventId'] as String?,
      lastEscalationAt: lastEscalationAtMs == null || lastEscalationAtMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastEscalationAtMs).toLocal(),
      lastEscalationAppLabel: raw['lastEscalationAppLabel'] as String?,
      lastEscalationTitle: raw['lastEscalationTitle'] as String?,
      lastEscalationBody: raw['lastEscalationBody'] as String?,
      lastEscalationAmountHint: raw['lastEscalationAmountHint'] as String?,
      lastEscalationRecipientHint:
          raw['lastEscalationRecipientHint'] as String?,
      lastEscalationUpiIdHint: raw['lastEscalationUpiIdHint'] as String?,
      lastEscalationPending: raw['lastEscalationPending'] as bool? ?? false,
    );
  }

  static PaymentProtectionState _parseState(String? rawState) {
    switch (rawState) {
      case 'amber':
        return PaymentProtectionState.amber;
      case 'red':
        return PaymentProtectionState.red;
      case 'monitoring':
        return PaymentProtectionState.monitoring;
      case 'inactive':
      default:
        return PaymentProtectionState.inactive;
    }
  }
}
