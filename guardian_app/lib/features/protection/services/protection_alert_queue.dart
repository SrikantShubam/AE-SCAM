import '../models/payment_protection_snapshot.dart';
import '../models/protection_alert.dart';
import '../payment_protection_bridge.dart';
import 'protection_alert_repository.dart';

class ProtectionAlertQueue {
  ProtectionAlertQueue._();

  static final ProtectionAlertQueue instance = ProtectionAlertQueue._();

  final ProtectionAlertRepository _repository =
      ProtectionAlertRepository.instance;

  Future<bool> captureFromSnapshot(PaymentProtectionSnapshot snapshot) async {
    final eventId = snapshot.lastEscalationEventId;
    if (!snapshot.lastEscalationPending || eventId == null || eventId.isEmpty) {
      return false;
    }

    final alert = GuardianProtectionAlert(
      id: eventId,
      type: GuardianProtectionAlert.typeChildAlert,
      status: GuardianProtectionAlertStatus.queued,
      state: snapshot.state.name,
      createdAt: snapshot.lastEscalationAt ?? DateTime.now(),
      synced: false,
      appLabel:
          snapshot.lastEscalationAppLabel ?? snapshot.lastMonitoredAppLabel,
      title: snapshot.lastEscalationTitle ?? snapshot.reviewTitle,
      body: snapshot.lastEscalationBody ?? snapshot.reviewBody,
      reason: snapshot.escalationReason,
      amountHint:
          snapshot.lastEscalationAmountHint ?? snapshot.detectedAmountHint,
      recipientHint:
          snapshot.lastEscalationRecipientHint ??
          snapshot.detectedRecipientHint,
      upiIdHint: snapshot.lastEscalationUpiIdHint ?? snapshot.detectedUpiIdHint,
    );

    await _repository.saveAlert(alert);

    await PaymentProtectionBridge.markEscalationHandled(eventId);
    return true;
  }
}
