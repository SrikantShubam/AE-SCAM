import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medication_dose_event.dart';
import '../models/medication_reminder_summary.dart';
import '../providers/medication_provider.dart';
import '../providers/medication_reminder_provider.dart';
import '../services/medication_alarm_platform_bridge.dart';

class MedicationReminderSection extends ConsumerWidget {
  const MedicationReminderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(medicationReminderSummaryProvider);
    final exactAlarmAsync = ref.watch(exactAlarmPermissionGrantedProvider);
    final alarmBridge = ref.watch(medicationAlarmPlatformBridgeProvider);

    final (accent, glow, icon) = switch (summary.statusTone) {
      MedicationReminderTone.dueNow => (
          const Color(0xFFFFF0DE),
          const Color(0x23F0A500),
          Icons.schedule_rounded,
        ),
      MedicationReminderTone.overdueAlarm => (
          const Color(0xFFFFE5E4),
          const Color(0x33C7302B),
          Icons.notifications_active_rounded,
        ),
      MedicationReminderTone.quiet => (
          const Color(0xFFE7F4F0),
          const Color(0x200E5E6D),
          Icons.medication_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A323C),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF0A323C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine reminders',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0A323C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.statusLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5F6F76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: glow,
                  blurRadius: summary.isAlarmActive ? 24 : 12,
                  spreadRadius: summary.isAlarmActive ? 1 : 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF0A323C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.reminderBody,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF29434A),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(label: summary.nextDoseLabel),
                    _Pill(label: summary.dosage),
                    _Pill(label: summary.statusLabel),
                  ],
                ),
                if (summary.isAlarmActive) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Alarm on this phone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFA12821),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ExactAlarmCard(
            exactAlarmAsync: exactAlarmAsync,
            onOpenSettings: () async {
              await alarmBridge.openExactAlarmSettings();
              ref.invalidate(exactAlarmPermissionGrantedProvider);
            },
            onRefresh: () => ref.invalidate(exactAlarmPermissionGrantedProvider),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 150,
                child: FilledButton(
                  onPressed: summary.canAcknowledge
                      ? () => _markDose(
                            context,
                            ref,
                            summary: summary,
                            status: MedicationDoseStatus.taken,
                            successMessage: 'Marked as taken.',
                          )
                      : null,
                  child: const Text('Taken'),
                ),
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton(
                  onPressed: summary.canAcknowledge
                      ? () => _markDose(
                            context,
                            ref,
                            summary: summary,
                            status: MedicationDoseStatus.skipped,
                            successMessage: 'Marked as skipped.',
                          )
                      : null,
                  child: const Text('Skip'),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextButton(
                  onPressed: summary.canAcknowledge
                      ? () => _snoozeReminder(context, ref, summary)
                      : null,
                  child: const Text('Remind me later'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markDose(
    BuildContext context,
    WidgetRef ref, {
    required MedicationReminderSummary summary,
    required MedicationDoseStatus status,
    required String successMessage,
  }) async {
    final scheduleId = summary.scheduleId;
    final scheduledAt = summary.scheduledAt;
    if (scheduleId == null || scheduledAt == null) {
      return;
    }

    try {
      final controller = ref.read(medicationControllerProvider);
      final eventId = summary.eventId ??
          (await controller.createDoseEvent(
            scheduleId: scheduleId,
            scheduledAt: scheduledAt,
          )).id;
      await controller.markDoseEventStatus(eventId: eventId, status: status);
      final alarmBridge = ref.read(medicationAlarmPlatformBridgeProvider);
      await alarmBridge.cancelOccurrence(
        medicationReminderOccurrenceKey(
          scheduleId: scheduleId,
          scheduledAt: scheduledAt,
        ),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not update this medicine reminder yet.'),
        ),
      );
    }
  }

  void _snoozeReminder(
    BuildContext context,
    WidgetRef ref,
    MedicationReminderSummary summary,
  ) {
    final scheduleId = summary.scheduleId;
    final scheduledAt = summary.scheduledAt;
    if (scheduleId == null || scheduledAt == null) {
      return;
    }

    ref
        .read(medicationReminderSnoozeProvider.notifier)
        .snooze(scheduleId: scheduleId, scheduledAt: scheduledAt);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guardian will remind again on this phone in 10 minutes.'),
      ),
    );
  }
}

class _ExactAlarmCard extends StatelessWidget {
  const _ExactAlarmCard({
    required this.exactAlarmAsync,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  final AsyncValue<bool> exactAlarmAsync;
  final Future<void> Function() onOpenSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return exactAlarmAsync.when(
      data: (granted) {
        final color = granted
            ? const Color(0xFFDDF4EA)
            : const Color(0xFFFFF0DE);
        final title = granted
            ? 'Medicine reminders are battery-friendly'
            : 'Medicine reminders are setting up';
        final body = granted
            ? 'Reminders may be up to 15 minutes late on some phones to save battery.'
            : 'Guardian is still checking reminder timing on this phone.';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF29434A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: granted
                        ? null
                        : () async {
                            await onOpenSettings();
                          },
                    child: Text(
                      granted
                          ? 'Reminder timing ready'
                          : 'Open reminder settings',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onRefresh,
                    child: const Text('Check again'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Guardian is checking reminder timing support on this phone.',
        ),
      ),
      error: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F0FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Guardian could not verify reminder timing support yet.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF29434A),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
