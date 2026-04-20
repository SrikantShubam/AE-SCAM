import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../medication/models/medication_reminder_summary.dart';
import '../models/child_dashboard_models.dart';
import '../providers/child_dashboard_provider.dart';

class ChildAdherenceSummaryCard extends ConsumerWidget {
  const ChildAdherenceSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(childMedicationAdherenceSummaryProvider);
    final tone = switch (summary.statusTone) {
      MedicationReminderTone.dueNow => const Color(0xFFFFF0DE),
      MedicationReminderTone.overdueAlarm => const Color(0xFFFFE5E4),
      MedicationReminderTone.quiet => const Color(0xFFDDF4EA),
    };

    return _SectionCard(
      title: 'Adherence summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.statusLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF0A323C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary.detail,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF29434A),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: summary.scheduledCount == 0
                        ? 0
                        : summary.handledCount / summary.scheduledCount,
                    backgroundColor: const Color(0xFFF3F5F7),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.statusTone == MedicationReminderTone.overdueAlarm
                          ? const Color(0xFFA12821)
                          : const Color(0xFF0E5E6D),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  summary.scheduledCount == 0
                      ? 'No doses scheduled today'
                      : '${summary.handledCount} of ${summary.scheduledCount} handled',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF29434A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: '${summary.takenCount} taken'),
              _Pill(label: '${summary.pendingCount} waiting'),
              _Pill(label: '${summary.skippedCount} skipped'),
            ],
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
