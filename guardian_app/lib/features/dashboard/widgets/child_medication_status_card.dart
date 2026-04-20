import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../medication/models/medication_reminder_summary.dart';
import '../../medication/providers/medication_reminder_provider.dart';

class ChildMedicationStatusCard extends ConsumerWidget {
  const ChildMedicationStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(medicationReminderSummaryProvider);
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

    return _SectionCard(
      title: 'Current medication status',
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
                      summary.title,
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
                  summary.nextDoseLabel,
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
                    _Pill(label: summary.statusLabel),
                    _Pill(label: summary.dosage),
                    _Pill(
                      label: summary.isAlarmActive
                          ? 'Alarm on this phone'
                          : 'Local reminder',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
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
