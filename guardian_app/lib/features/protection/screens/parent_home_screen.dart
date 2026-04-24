import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_db.dart';
import '../../medication/services/medication_alarm_platform_bridge.dart';
import '../../medication/services/medication_notification_gateway_impl.dart';
import '../../medication/services/medication_reminder_delivery_service.dart';
import '../../medication/services/medication_reminder_orchestrator.dart';
import '../../medication/services/medication_reminder_service.dart';
import '../../medication/services/medication_repository.dart';
import '../../medication/widgets/medication_reminder_section.dart';
import '../../onboarding/services/battery_optimization_bridge.dart';
import '../models/payment_protection_snapshot.dart';
import '../payment_protection_bridge.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with WidgetsBindingObserver {
  static const _batteryOptimizationCompletedKey =
      'battery_optimization_step_completed';
  static const _batteryOptimizationSkippedKey =
      'battery_optimization_step_skipped';
  late Future<PaymentProtectionSnapshot> _snapshotFuture;
  late final MedicationReminderDeliveryService _medicationDeliveryService;
  bool _showBatteryBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _medicationDeliveryService = MedicationReminderDeliveryService(
      repository: MedicationRepository(localDb: LocalDb.instance),
      orchestrator: MedicationReminderOrchestrator(
        reminderService: MedicationReminderService(),
        notificationGateway: PlatformMedicationNotificationGateway(
          platformBridge: MedicationAlarmPlatformBridge(),
        ),
      ),
    );
    _snapshotFuture = _loadSnapshot();
    _primeMedicationReminders();
    _loadBatteryBannerState();
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

  Future<PaymentProtectionSnapshot> _loadSnapshot() {
    return PaymentProtectionBridge.loadSnapshot();
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
    await _primeMedicationReminders();
    await _loadBatteryBannerState();
  }

  Future<void> _loadBatteryBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_batteryOptimizationCompletedKey) ?? false;
    final skipped = prefs.getBool(_batteryOptimizationSkippedKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _showBatteryBanner = skipped && !completed;
    });
  }

  Future<void> _primeMedicationReminders() async {
    final now = DateTime.now();
    await _medicationDeliveryService.scheduleWindow(
      from: now.subtract(const Duration(minutes: 1)),
      until: now.add(const Duration(days: 2)),
    );
  }

  Future<void> _openAccessibilitySettings() async {
    final opened = await PaymentProtectionBridge.openAccessibilitySettings();
    if (!opened) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not open Android settings yet.'),
        ),
      );
      return;
    }
    await _refresh();
  }

  Future<void> _openBatteryOptimizationSettingsFromBanner() async {
    final opened =
        await BatteryOptimizationBridge.openBatteryOptimizationSettings();
    if (!opened) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not open battery settings yet.'),
        ),
      );
      return;
    }
    await _loadBatteryBannerState();
  }

  Future<void> _markBatteryOptimizationCompletedFromBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batteryOptimizationCompletedKey, true);
    await prefs.setBool(_batteryOptimizationSkippedKey, false);
    if (!mounted) {
      return;
    }
    setState(() {
      _showBatteryBanner = false;
    });
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/home/parent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF0E5E6D),
          child: FutureBuilder<PaymentProtectionSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? PaymentProtectionSnapshot.inactive();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  _ParentHeader(onBack: _handleBack),
                  const SizedBox(height: 28),
                  _ParentHeroCard(data: data),
                  const SizedBox(height: 20),
                  if (!data.accessibilityHealthEnabled) ...[
                    const _AccessibilityHealthBanner(),
                    const SizedBox(height: 20),
                  ],
                  _ProtectionSummaryCard(data: data),
                  const SizedBox(height: 20),
                  const MedicationReminderSection(),
                  const SizedBox(height: 20),
                  if (data.lastEscalationEventId != null) ...[
                    _FamilyFollowUpCard(data: data),
                    const SizedBox(height: 20),
                  ],
                  if (_showBatteryBanner) ...[
                    _BatteryOptimizationBanner(
                      onOpenSettings:
                          _openBatteryOptimizationSettingsFromBanner,
                      onMarkCompleted:
                          _markBatteryOptimizationCompletedFromBanner,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _ActionPanel(
                    data: data,
                    onEnable: _openAccessibilitySettings,
                  ),
                  const SizedBox(height: 20),
                  _PermissionsAndPrivacyCard(
                    onOpen: () => context.push('/disclosure/accessibility'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pull down to refresh if you just came back from a payment app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F6F76),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParentHeader extends StatelessWidget {
  const _ParentHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0A323C),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Image.asset('assets/branding/guardian_logo.png', height: 48, width: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guardian',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Parent view',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F6F76),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentHeroCard extends StatelessWidget {
  const _ParentHeroCard({required this.data});

  final PaymentProtectionSnapshot data;

  @override
  Widget build(BuildContext context) {
    final title = switch (data.state) {
      PaymentProtectionState.inactive => 'Live payment protection is off',
      PaymentProtectionState.monitoring => 'Guardian is standing by quietly',
      PaymentProtectionState.amber =>
        'Guardian asked your parent to double-check',
      PaymentProtectionState.red =>
        'Guardian noticed something that looks suspicious',
    };
    final subtitle = switch (data.state) {
      PaymentProtectionState.inactive =>
        'Turn the permission on so Guardian can pause suspicious payment flows before money is sent.',
      PaymentProtectionState.monitoring =>
        'When a real payment screen appears, Guardian can slow the moment down and ask for one more careful look.',
      PaymentProtectionState.amber =>
        data.reviewBody ??
            'Guardian noticed a payment that needed another careful review.',
      PaymentProtectionState.red =>
        data.reviewBody ??
            'Guardian noticed a higher-risk payment flow and slowed it down.',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE7F4F0), Color(0xFFF8F2DD)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A323C),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E5E6D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Protected',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF29434A),
              height: 1.45,
            ),
          ),
          if (data.lastMonitoredAppLabel != null ||
              data.lastMonitoredAt != null) ...[
            const SizedBox(height: 18),
            Text(
              _latestActivityLabel(data),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4B5D63),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _latestActivityLabel(PaymentProtectionSnapshot data) {
    final parts = <String>[];
    if (data.lastMonitoredAppLabel != null) {
      parts.add('Last seen in ${data.lastMonitoredAppLabel}');
    }
    if (data.lastMonitoredAt != null) {
      parts.add(_formatTime(data.lastMonitoredAt!));
    }
    return parts.join(' | ');
  }

  String _formatTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _ProtectionSummaryCard extends StatelessWidget {
  const _ProtectionSummaryCard({required this.data});

  final PaymentProtectionSnapshot data;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (data.detectedRecipientHint != null)
        'Recipient ${data.detectedRecipientHint!}',
      if (data.detectedAmountHint != null) 'Amount ${data.detectedAmountHint!}',
      if (data.detectedUpiIdHint != null) 'UPI ID ${data.detectedUpiIdHint!}',
    ];
    final reasons = data.reasons.take(2).toList(growable: false);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protection summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatePill(
                label: switch (data.state) {
                  PaymentProtectionState.inactive => 'Off',
                  PaymentProtectionState.monitoring => 'Monitoring',
                  PaymentProtectionState.amber => 'Reviewing',
                  PaymentProtectionState.red => 'Strong warning',
                },
                color: switch (data.state) {
                  PaymentProtectionState.inactive => const Color(0xFFE7ECEF),
                  PaymentProtectionState.monitoring => const Color(0xFFDDF4EA),
                  PaymentProtectionState.amber => const Color(0xFFFFF0DE),
                  PaymentProtectionState.red => const Color(0xFFFFE5E4),
                },
              ),
              if (data.isNewRecipient)
                const _StatePill(
                  label: 'New recipient',
                  color: Color(0xFFFFF0DE),
                ),
              if (data.hasHighAmount)
                const _StatePill(
                  label: 'High amount',
                  color: Color(0xFFFFE1C2),
                ),
              if (data.hasSuspiciousLanguage)
                const _StatePill(
                  label: 'Pressure language',
                  color: Color(0xFFFFE5E4),
                ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              details.join(' | '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF455B63),
                height: 1.4,
              ),
            ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xFF0E5E6D),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF29434A),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FamilyFollowUpCard extends StatelessWidget {
  const _FamilyFollowUpCard({required this.data});

  final PaymentProtectionSnapshot data;

  @override
  Widget build(BuildContext context) {
    final detailParts = <String>[
      if (data.lastEscalationAppLabel != null) data.lastEscalationAppLabel!,
      if (data.lastEscalationAmountHint != null) data.lastEscalationAmountHint!,
      if (data.lastEscalationRecipientHint != null)
        data.lastEscalationRecipientHint!,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.lastEscalationPending
                ? 'Family follow-up is waiting'
                : 'Family follow-up was recorded',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF183A5A),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.lastEscalationBody ??
                data.escalationReason ??
                'Guardian recorded a stronger event so family can check in.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF234863),
              height: 1.45,
            ),
          ),
          if (detailParts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detailParts.join(' | '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF355A77),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.data, required this.onEnable});

  final PaymentProtectionSnapshot data;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final helperText = data.isInactive
        ? 'Guardian can still help after the fact, but it cannot warn before money leaves the account.'
        : 'Guardian only shows a warning when it sees a real payment screen with enough visible detail to review.';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Next action',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onEnable,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E5E6D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('Open Android Accessibility settings'),
          ),
          const SizedBox(height: 12),
          if (!data.isInactive) ...[
            OutlinedButton(
              onPressed: onEnable,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0E5E6D),
                side: const BorderSide(color: Color(0xFFB8CDD2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Open Android Accessibility settings'),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF455B63),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsAndPrivacyCard extends StatelessWidget {
  const _PermissionsAndPrivacyCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E8),
        borderRadius: BorderRadius.circular(28),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5E6D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy and permissions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0A323C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review what Guardian can see, why it needs that access, and how to turn the permission off at any time.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF455B63),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF0A323C)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryOptimizationBanner extends StatelessWidget {
  const _BatteryOptimizationBanner({
    required this.onOpenSettings,
    required this.onMarkCompleted,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onMarkCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish battery setup for medicine reminders',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You skipped battery optimization during onboarding. Some phones stop reminders to save battery. Complete this once so Guardian can remind your parent on time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF455B63),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onOpenSettings,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0E5E6D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open battery optimization settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onMarkCompleted,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0E5E6D),
              side: const BorderSide(color: Color(0xFFB8CDD2)),
            ),
            child: const Text('I completed this'),
          ),
        ],
      ),
    );
  }
}

class _AccessibilityHealthBanner extends StatelessWidget {
  const _AccessibilityHealthBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9E6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guardian payment protection paused',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF7A1F16),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your parent device has accessibility protection turned off. Please reopen Android accessibility settings and re-enable Guardian.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7A1F16),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

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
      child: child,
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
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
