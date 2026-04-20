import '../models/medication_reminder_plan.dart';
import 'medication_alarm_platform_bridge.dart';
import 'medication_reminder_orchestrator.dart';

class PlatformMedicationNotificationGateway
    implements MedicationNotificationGateway {
  const PlatformMedicationNotificationGateway({
    required MedicationAlarmPlatformBridge platformBridge,
  }) : _platformBridge = platformBridge;

  final MedicationAlarmPlatformBridge _platformBridge;

  @override
  Future<void> scheduleInAppReminder({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {
    await _platformBridge.scheduleTrigger(
      occurrence: occurrence,
      trigger: trigger,
    );
  }

  @override
  Future<void> scheduleAlarm({
    required MedicationDoseOccurrence occurrence,
    required ReminderTrigger trigger,
  }) async {
    await _platformBridge.scheduleTrigger(
      occurrence: occurrence,
      trigger: trigger,
    );
  }

  @override
  Future<void> cancelOccurrence(String occurrenceId) async {
    await _platformBridge.cancelOccurrence(occurrenceId);
  }
}
