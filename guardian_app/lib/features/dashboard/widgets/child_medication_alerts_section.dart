import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../medication/models/medication_reminder_summary.dart';
import '../models/child_dashboard_models.dart';
import '../providers/child_dashboard_provider.dart';

class ChildMedicationAlertsSection extends ConsumerWidget {
  const ChildMedicationAlertsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(childMedicationAlertFeedProvider);

    return _SectionCard(
      title: 'Recent medication alerts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alerts
            .map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AlertTile(alert: alert),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final ChildMedicationAlertItem alert;

  @override
  Widget build(BuildContext context) {
    final (accent, toneColor, icon) = switch (alert.tone) {
      MedicationReminderTone.dueNow => (
          const Color(0xFFFFF0DE),
          const Color(0xFF8C4D1D),
          Icons.schedule_rounded,
        ),
      MedicationReminderTone.overdueAlarm => (
          const Color(0xFFFFE5E4),
          const Color(0xFFA12821),
          Icons.notifications_active_rounded,
        ),
      MedicationReminderTone.quiet => (
          const Color(0xFFE7F4F0),
          const Color(0xFF185B4E),
          Icons.info_outline_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: toneColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(label: alert.badge),
                    if (alert.isPlaceholder)
                      const _Badge(label: 'Local placeholder'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0A323C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alert.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF29434A),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF29434A),
          fontWeight: FontWeight.w700,
        ),
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
