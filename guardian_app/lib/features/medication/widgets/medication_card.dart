import 'package:flutter/material.dart';

import '../models/medication_schedule.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.schedule,
    this.onEdit,
    this.onDeactivate,
    this.onReactivate,
  });

  final MedicationSchedule schedule;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = onEdit != null;
    final canDeactivate = schedule.isActive && onDeactivate != null;
    final canReactivate = !schedule.isActive && onReactivate != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        schedule.dosage,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF0E5E6D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _ActiveBadge(isActive: schedule.isActive),
                if (canEdit || canDeactivate || canReactivate) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<_MedicationMenuAction>(
                    tooltip: 'Medication actions',
                    onSelected: (value) {
                      switch (value) {
                        case _MedicationMenuAction.edit:
                          onEdit?.call();
                        case _MedicationMenuAction.deactivate:
                          onDeactivate?.call();
                        case _MedicationMenuAction.reactivate:
                          onReactivate?.call();
                      }
                    },
                    itemBuilder: (context) {
                      return <PopupMenuEntry<_MedicationMenuAction>>[
                        if (canEdit)
                          const PopupMenuItem(
                            value: _MedicationMenuAction.edit,
                            child: Text('Edit'),
                          ),
                        if (canDeactivate)
                          const PopupMenuItem(
                            value: _MedicationMenuAction.deactivate,
                            child: Text('Deactivate'),
                          ),
                        if (canReactivate)
                          const PopupMenuItem(
                            value: _MedicationMenuAction.reactivate,
                            child: Text('Reactivate'),
                          ),
                      ];
                    },
                  ),
                ],
              ],
            ),
            if (schedule.purpose != null && schedule.purpose!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'For ${schedule.purpose!}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF29434A),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(label: _formatDays(schedule.activeDays)),
                _Pill(label: _formatTimes(schedule.doseTimes)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(Set<MedicationWeekday> activeDays) {
    if (activeDays.length == MedicationWeekday.values.length) {
      return 'Every day';
    }
    final ordered = MedicationWeekday.values
        .where(activeDays.contains)
        .map(_weekdayLabel)
        .toList(growable: false);
    return ordered.join(', ');
  }

  String _weekdayLabel(MedicationWeekday day) {
    return switch (day) {
      MedicationWeekday.mon => 'Mon',
      MedicationWeekday.tue => 'Tue',
      MedicationWeekday.wed => 'Wed',
      MedicationWeekday.thu => 'Thu',
      MedicationWeekday.fri => 'Fri',
      MedicationWeekday.sat => 'Sat',
      MedicationWeekday.sun => 'Sun',
    };
  }

  String _formatTimes(List<String> rawTimes) {
    final sorted = rawTimes.toList(growable: false)
      ..sort((a, b) => _minutesOfDay(a).compareTo(_minutesOfDay(b)));
    final labels = sorted.map(_toFriendlyTime).join(' • ');
    return sorted.length == 1 ? labels : '$labels (${sorted.length} times)';
  }

  int _minutesOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  String _toFriendlyTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return value;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return value;
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour == 0
        ? 12
        : (hour > 12 ? hour - 12 : hour);
    return '$normalizedHour:${minute.toString().padLeft(2, '0')} $period';
  }
}

enum _MedicationMenuAction { edit, deactivate, reactivate }

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFDDF4EA) : const Color(0xFFFFF0DE);
    final textColor = isActive
        ? const Color(0xFF185B4E)
        : const Color(0xFF8C4D1D);
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF29434A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
