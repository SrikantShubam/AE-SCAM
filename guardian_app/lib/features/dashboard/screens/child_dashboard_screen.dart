import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../medication/providers/medication_provider.dart';
import '../../medication/providers/medication_reminder_provider.dart';
import '../../protection/services/emergency_disable_sync_service.dart';
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
  bool _emergencyDisabled = false;
  bool _toggleBusy = false;
  final EmergencyDisableSyncService _emergencyDisableSyncService =
      EmergencyDisableSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEmergencyState();
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
    await _loadEmergencyState();
  }

  Future<void> _loadEmergencyState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _emergencyDisabled = prefs.getBool('emergency_disabled') ?? false;
    });
  }

  Future<void> _onEmergencyDisableLongPress() async {
    if (_toggleBusy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm emergency pause'),
          content: Text(
            _emergencyDisabled
                ? 'Long-press confirmed. Resume protection on the parent device?'
                : 'Long-press confirmed. Pause protection on the parent device?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _toggleBusy = true;
    });
    try {
      final value = await _emergencyDisableSyncService.toggleFromCaregiver();
      if (!mounted) {
        return;
      }
      setState(() {
        _emergencyDisabled = value;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not update emergency disable yet.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _toggleBusy = false;
        });
      }
    }
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
              const SizedBox(height: 20),
              GestureDetector(
                onLongPress: _onEmergencyDisableLongPress,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Emergency disable (long-press to confirm)',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (_toggleBusy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: _emergencyDisabled,
                          onChanged: null,
                        ),
                    ],
                  ),
                ),
              ),
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
