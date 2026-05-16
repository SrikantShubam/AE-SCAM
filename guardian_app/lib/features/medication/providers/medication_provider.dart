import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_db.dart';
import '../models/medication_dose_event.dart';
import '../models/medication_schedule.dart';
import '../services/medication_alarm_platform_bridge.dart';
import '../services/medication_notification_gateway_impl.dart';
import '../services/medication_repository.dart';
import '../services/medication_schedule_deletion_service.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return MedicationRepository(localDb: LocalDb.instance);
});

final medicationAlarmPlatformBridgeProvider =
    Provider<MedicationAlarmPlatformBridge>((ref) {
      return MedicationAlarmPlatformBridge();
    });

final activeMedicationSchedulesProvider =
    FutureProvider<List<MedicationSchedule>>((ref) async {
      final repository = ref.watch(medicationRepositoryProvider);
      return repository.listActiveSchedules();
    });

final selectedMedicationDateProvider =
    NotifierProvider<SelectedMedicationDateNotifier, DateTime>(
      SelectedMedicationDateNotifier.new,
    );

final medicationDoseEventsForSelectedDateProvider =
    FutureProvider<List<MedicationDoseEvent>>((ref) async {
      final repository = ref.watch(medicationRepositoryProvider);
      final date = ref.watch(selectedMedicationDateProvider);
      return repository.listDoseEventsForDate(date);
    });

final allMedicationSchedulesProvider = FutureProvider<List<MedicationSchedule>>(
  (ref) async {
    final repository = ref.watch(medicationRepositoryProvider);
    return repository.listSchedules();
  },
);

final medicationControllerProvider = Provider<MedicationController>((ref) {
  return MedicationController(
    ref,
    ref.watch(medicationRepositoryProvider),
    MedicationScheduleDeletionService(
      repository: ref.watch(medicationRepositoryProvider),
      notificationGateway: PlatformMedicationNotificationGateway(
        platformBridge: ref.watch(medicationAlarmPlatformBridgeProvider),
      ),
    ),
  );
});

final exactAlarmPermissionGrantedProvider = FutureProvider<bool>((ref) async {
  final bridge = ref.watch(medicationAlarmPlatformBridgeProvider);
  return bridge.isExactAlarmPermissionGranted();
});

class SelectedMedicationDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime value) {
    state = value;
  }

  void reset() {
    state = DateTime.now();
  }
}

class MedicationController {
  MedicationController(this._ref, this._repository, this._deletionService);

  final Ref _ref;
  final MedicationRepository _repository;
  final MedicationScheduleDeletionService _deletionService;

  Future<MedicationSchedule> saveSchedule(MedicationSchedule schedule) async {
    final saved = await _repository.upsertSchedule(schedule);
    _invalidateScheduleQueries();
    return saved;
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _deletionService.deleteSchedule(scheduleId);
    _invalidateScheduleQueries();
  }

  Future<MedicationDoseEvent> createDoseEvent({
    required String scheduleId,
    required DateTime scheduledAt,
  }) async {
    final event = await _repository.createDoseEvent(
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
    );
    _invalidateDoseQueries();
    return event;
  }

  Future<MedicationDoseEvent> markDoseEventStatus({
    required String eventId,
    required MedicationDoseStatus status,
  }) async {
    final updated = await _repository.markDoseEventStatus(
      eventId: eventId,
      status: status,
    );
    _invalidateDoseQueries();
    return updated;
  }

  Future<MedicationDoseEvent> updateDoseEvent({
    required String eventId,
    MedicationDoseStatus? status,
    MedicationEscalationLevel? escalationLevel,
    DateTime? reminderSentAt,
    DateTime? actedAt,
  }) async {
    final updated = await _repository.updateDoseEvent(
      eventId: eventId,
      status: status,
      escalationLevel: escalationLevel,
      reminderSentAt: reminderSentAt,
      actedAt: actedAt,
    );
    _invalidateDoseQueries();
    return updated;
  }

  void _invalidateScheduleQueries() {
    _ref.invalidate(activeMedicationSchedulesProvider);
    _ref.invalidate(allMedicationSchedulesProvider);
  }

  void _invalidateDoseQueries() {
    _ref.invalidate(medicationDoseEventsForSelectedDateProvider);
  }
}
