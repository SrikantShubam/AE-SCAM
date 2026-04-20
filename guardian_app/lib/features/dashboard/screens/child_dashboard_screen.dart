import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../medication/providers/medication_provider.dart';
import '../../medication/providers/medication_reminder_provider.dart';
import '../providers/child_dashboard_provider.dart';
import '../widgets/child_adherence_summary_card.dart';
import '../widgets/child_dashboard_header_card.dart';
import '../widgets/child_medication_alerts_section.dart';
import '../widgets/child_medication_status_card.dart';
import '../widgets/child_protection_activity_section.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(activeMedicationSchedulesProvider);
    ref.invalidate(medicationDoseEventsForSelectedDateProvider);
    ref.invalidate(medicationReminderSummaryProvider);
    ref.invalidate(childMedicationAdherenceSummaryProvider);
    ref.invalidate(childMedicationAlertFeedProvider);
    ref.invalidate(childProtectionAlertsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(medicationReminderSummaryProvider);
    final headerTitle = summary.title == 'No medicine reminders yet'
        ? 'No medicine reminders yet'
        : summary.title;
    final headerSubtitle = summary.reminderBody;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF0E5E6D),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              ChildDashboardHeaderCard(
                title: headerTitle,
                subtitle: headerSubtitle,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => context.push('/medications/setup'),
                  icon: const Icon(Icons.medication_outlined),
                  label: const Text('Manage medications'),
                ),
              ),
              const SizedBox(height: 20),
              const ChildMedicationStatusCard(),
              const SizedBox(height: 20),
              const ChildMedicationAlertsSection(),
              const SizedBox(height: 20),
              const ChildAdherenceSummaryCard(),
              const SizedBox(height: 20),
              const ChildProtectionActivitySection(),
              const SizedBox(height: 24),
              Text(
                'Pull down to refresh local medication and protection data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F6F76),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
