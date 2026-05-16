import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medication_schedule.dart';
import '../providers/medication_provider.dart';
import '../widgets/medication_card.dart';
import 'medication_form_screen.dart';

class MedicationListScreen extends ConsumerWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(allMedicationSchedulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medications')),
      body: SafeArea(
        child: schedulesAsync.when(
          data: (allSchedules) {
            if (allSchedules.isEmpty) {
              return _EmptyMedicationState(
                onAddMedication: () => _openForm(context),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allMedicationSchedulesProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  _SectionHeader(
                    title: 'Medication schedule',
                    subtitle:
                        '${allSchedules.length} medication${allSchedules.length == 1 ? '' : 's'} saved for this parent',
                  ),
                  const SizedBox(height: 10),
                  ...allSchedules.map(
                    (schedule) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedicationCard(
                        schedule: schedule,
                        onEdit: () => _openForm(context, schedule: schedule),
                        onDelete: () => _confirmDelete(context, ref, schedule),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Guardian could not load medications right now.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(allMedicationSchedulesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add medication'),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    MedicationSchedule? schedule,
  }) async {
    await Navigator.of(context).push<MedicationSchedule>(
      MaterialPageRoute<MedicationSchedule>(
        builder: (_) => MedicationFormScreen(initialSchedule: schedule),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MedicationSchedule schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete medication?'),
          content: Text(
            'Delete ${schedule.name}? This permanently removes reminders and past local history for this medication.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    try {
      final controller = ref.read(medicationControllerProvider);
      await controller.deleteSchedule(schedule.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${schedule.name} was deleted.')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not delete this medication yet.'),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5F6F76),
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _EmptyMedicationState extends StatelessWidget {
  const _EmptyMedicationState({required this.onAddMedication});

  final VoidCallback onAddMedication;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.medication_outlined,
              size: 56,
              color: Color(0xFF0E5E6D),
            ),
            const SizedBox(height: 14),
            Text(
              'No medications added yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Add your parent\'s first medicine with days and times so Guardian can start reminders.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAddMedication,
              child: const Text('Add medication'),
            ),
          ],
        ),
      ),
    );
  }
}
