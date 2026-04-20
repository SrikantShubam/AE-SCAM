import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/guardian_brand_mark.dart';
import '../models/payment_protection_snapshot.dart';
import '../payment_protection_bridge.dart';
import '../services/protection_alert_queue.dart';
import '../widgets/protection_decision_support_card.dart';
import '../widgets/protection_review_context_card.dart';

class ProtectionHomeScreen extends StatefulWidget {
  const ProtectionHomeScreen({super.key});

  @override
  State<ProtectionHomeScreen> createState() => _ProtectionHomeScreenState();
}

class _ProtectionHomeScreenState extends State<ProtectionHomeScreen>
    with WidgetsBindingObserver {
  late Future<PaymentProtectionSnapshot> _snapshotFuture;
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<PaymentProtectionSnapshot> _loadSnapshot() async {
    final snapshot = await PaymentProtectionBridge.loadSnapshot();
    try {
      await ProtectionAlertQueue.instance.captureFromSnapshot(snapshot);
    } catch (_) {
      // Keep the protection screen usable even if local queueing fails.
    }
    _syncCooldown(snapshot);
    return snapshot;
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  void _syncCooldown(PaymentProtectionSnapshot snapshot) {
    _cooldownTimer?.cancel();
    if (!snapshot.isRed || snapshot.cooldownSeconds <= 0) {
      _cooldownRemaining = 0;
      return;
    }

    _cooldownRemaining = snapshot.cooldownSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _cooldownRemaining = 0;
        });
        return;
      }
      setState(() {
        _cooldownRemaining -= 1;
      });
    });
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await PaymentProtectionBridge.openAccessibilitySettings();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accessibility settings bridge is not available yet.'),
        ),
      );
      return;
    }
    await _refresh();
  }

  Future<void> _handleBack() async {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    if (!mounted) {
      return;
    }

    if (userRole == 'parent') {
      context.go('/home/parent');
    } else if (userRole == 'child') {
      context.go('/home/child');
    } else {
      context.go('/onboarding/welcome');
    }
  }

  void _showDecisionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _handleBack()),
        title: const Text('Guardian'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<PaymentProtectionSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              final data =
                  snapshot.data ?? PaymentProtectionSnapshot.inactive();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFDDF4EA), Color(0xFFF7F2DE)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GuardianBrandMark(),
                        const SizedBox(height: 20),
                        Text(
                          'Payment protection',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFF0E5E6D),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Guardian watches for payment screens in Google Pay, PhonePe, Paytm, and similar apps. When it sees a real send-money flow, it asks the elder user to pause before continuing.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatusCard(snapshot: data),
                  if (data.isInactive) ...[
                    const SizedBox(height: 16),
                    _InactiveHomeExperience(
                      onOpenSettings: _openAccessibilitySettings,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    ProtectionReviewContextCard(snapshot: data),
                    const SizedBox(height: 16),
                    _InterventionCard(
                      snapshot: data,
                      cooldownRemaining: _cooldownRemaining,
                      onSafeExit: () => _showDecisionMessage(
                        'Guardian recorded a safe exit. Stay in Guardian and review the payment request before returning.',
                      ),
                      onProceed: () => _showDecisionMessage(
                        'Guardian recorded that the user still wants to proceed. Return to the payment app only if the details are fully expected.',
                      ),
                    ),
                    if (data.isWarning) ...[
                      const SizedBox(height: 16),
                      ProtectionDecisionSupportCard(snapshot: data),
                    ],
                    if (data.lastEscalationEventId != null) ...[
                      const SizedBox(height: 16),
                      _FamilyAlertCard(snapshot: data),
                    ],
                    const SizedBox(height: 16),
                    _ActionCard(
                      snapshot: data,
                      onOpenSettings: _openAccessibilitySettings,
                      onRefresh: _refresh,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FamilyAlertCard extends StatelessWidget {
  const _FamilyAlertCard({required this.snapshot});

  final PaymentProtectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final title = snapshot.lastEscalationPending
        ? 'Family alert queued'
        : 'Last family alert recorded';
    final detailParts = <String>[
      if (snapshot.lastEscalationAppLabel != null)
        snapshot.lastEscalationAppLabel!,
      if (snapshot.lastEscalationRecipientHint != null)
        'Recipient ${snapshot.lastEscalationRecipientHint!}',
      if (snapshot.lastEscalationAmountHint != null)
        'Amount ${snapshot.lastEscalationAmountHint!}',
    ];

    return Card(
      color: const Color(0xFFE8F1FB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              snapshot.escalationReason ??
                  'Guardian recorded a stronger payment-risk event so the child side can follow up.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (detailParts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                detailParts.join(' • '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});

  final PaymentProtectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (title, subtitle, tint) = switch (snapshot.state) {
      PaymentProtectionState.inactive => (
        'Payment protection is off',
        'Guardian is not watching payment screens yet. Turn this on once to add an extra check before money leaves the account.',
        colorScheme.outline,
      ),
      PaymentProtectionState.monitoring => (
        'Watching for payment review',
        'Guardian is waiting for a real payment screen with amount or recipient details.',
        colorScheme.primary,
      ),
      PaymentProtectionState.amber => (
        'Payment review',
        'Guardian found a payment screen and wants the user to double-check before continuing.',
        const Color(0xFF8C5A00),
      ),
      PaymentProtectionState.red => (
        'Stop and verify',
        'Guardian found a higher-risk payment flow and is holding the continue path behind a cooldown.',
        colorScheme.error,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: tint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(subtitle, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            _StatusChip(snapshot: snapshot),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.snapshot});

  final PaymentProtectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (snapshot.state) {
      PaymentProtectionState.inactive => (
        'Off',
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
      PaymentProtectionState.monitoring => (
        'Monitoring',
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      PaymentProtectionState.amber => (
        'Amber review',
        const Color(0xFFFFF0D8),
        const Color(0xFF8C5A00),
      ),
      PaymentProtectionState.red => (
        'Red stop',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InactiveHomeExperience extends StatelessWidget {
  const _InactiveHomeExperience({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFFE7F0FB),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live payment protection',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If you turn on the Accessibility permission, Guardian can warn before money is sent on a risky payment screen. Without it, Guardian still works with manual payment checks, but live payment protection stays off.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const _AccessBullet(
              text: 'Show an on-screen review while the payment app is open.',
            ),
            const SizedBox(height: 12),
            const _AccessBullet(
              text:
                  'Point out amount, recipient, or UPI details that need a second check.',
            ),
            const SizedBox(height: 12),
            const _AccessBullet(
              text:
                  'Never send money, press pay, or take away the user\'s final decision.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Open Android Accessibility settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  const _InterventionCard({
    required this.snapshot,
    required this.cooldownRemaining,
    required this.onSafeExit,
    required this.onProceed,
  });

  final PaymentProtectionSnapshot snapshot;
  final int cooldownRemaining;
  final VoidCallback onSafeExit;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.isWarning) {
      return const SizedBox.shrink();
    }

    final title =
        snapshot.reviewTitle ?? 'Review this payment before you continue';
    final body =
        snapshot.reviewBody ??
        'Guardian noticed a payment screen and wants the user to pause before continuing.';
    final safeLabel = snapshot.safeExitLabel ?? 'Go back to safety';
    final proceedLabel = snapshot.proceedLabel ?? 'Yes, continue';
    final canProceed = !snapshot.isRed || cooldownRemaining <= 0;

    return Card(
      color: snapshot.isRed ? const Color(0xFFFFE5E4) : const Color(0xFFFFF0DE),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: snapshot.isRed
                    ? const Color(0xFFA12821)
                    : const Color(0xFF8C4D1D),
              ),
            ),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
            if (snapshot.hasElevatedRiskSignals) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (snapshot.hasHighAmount)
                    const _RiskPill(
                      label: 'High amount',
                      background: Color(0xFFFFE1C2),
                      foreground: Color(0xFF8C4D1D),
                    ),
                  if (snapshot.hasSuspiciousLanguage)
                    const _RiskPill(
                      label: 'Suspicious wording',
                      background: Color(0xFFFFDDD8),
                      foreground: Color(0xFFA12821),
                    ),
                  if (snapshot.recipientRecentlyChanged)
                    const _RiskPill(
                      label: 'Recipient changed',
                      background: Color(0xFFFFDDD8),
                      foreground: Color(0xFFA12821),
                    ),
                  if (snapshot.isNewRecipient)
                    const _RiskPill(
                      label: 'New recipient',
                      background: Color(0xFFFFF0DE),
                      foreground: Color(0xFF8C4D1D),
                    ),
                  if (snapshot.isRecipientKnown &&
                      (snapshot.detectedRecipientHint != null ||
                          snapshot.detectedUpiIdHint != null))
                    const _RiskPill(
                      label: 'Trusted recipient',
                      background: Color(0xFFE0F2F1),
                      foreground: Color(0xFF0E5E6D),
                    ),
                ],
              ),
            ],
            if (snapshot.escalationRecommended &&
                snapshot.escalationReason != null) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: snapshot.isRed
                        ? const Color(0xFFA12821)
                        : const Color(0xFF8C4D1D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      snapshot.escalationReason!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: snapshot.isRed
                            ? const Color(0xFFA12821)
                            : const Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Pause and check:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('1. Who asked for this payment?'),
            const SizedBox(height: 6),
            const Text('2. Does the recipient or UPI ID look correct?'),
            const SizedBox(height: 6),
            const Text('3. Does the amount look fully expected?'),
            if (snapshot.isRed) ...[
              const SizedBox(height: 16),
              Text(
                cooldownRemaining > 0
                    ? 'You can continue in $cooldownRemaining seconds.'
                    : 'Cooldown complete. Continue only if the payment is fully expected.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onSafeExit, child: Text(safeLabel)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: canProceed ? onProceed : null,
              child: Text(canProceed ? proceedLabel : 'Wait before continuing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.snapshot,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  final PaymentProtectionSnapshot snapshot;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = snapshot.isInactive
        ? 'Open Android Accessibility settings'
        : 'Refresh payment status';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What you can do',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: snapshot.isInactive ? onOpenSettings : onRefresh,
              child: Text(primaryLabel),
            ),
            if (!snapshot.isInactive) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('Turn off live payment protection'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              snapshot.isWarning
                  ? 'Guardian is showing payment review because it found a real send-money screen with visible payment clues.'
                  : snapshot.isInactive
                  ? 'When you open Android Accessibility settings, you give Guardian the Accessibility permission once so it can watch payment screens for you.'
                  : 'Guardian stays quiet until it sees a payment screen with enough visible detail to review.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessBullet extends StatelessWidget {
  const _AccessBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.check_circle_outline, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
