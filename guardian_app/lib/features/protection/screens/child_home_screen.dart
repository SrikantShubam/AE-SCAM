import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/protection_alert.dart';
import '../services/protection_alert_repository.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen>
    with WidgetsBindingObserver {
  final ProtectionAlertRepository _repository =
      ProtectionAlertRepository.instance;

  late Future<List<GuardianProtectionAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alertsFuture = _loadAlerts();
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

  Future<List<GuardianProtectionAlert>> _loadAlerts() {
    return _repository.listAlerts();
  }

  Future<void> _refresh() async {
    setState(() {
      _alertsFuture = _loadAlerts();
    });
    await _alertsFuture;
  }

  Future<void> _markSeen(GuardianProtectionAlert alert) async {
    if (!alert.isQueued) {
      return;
    }
    await _repository.markSeen(alert.id);
    await _refresh();
  }

  Future<void> _markResolved(GuardianProtectionAlert alert) async {
    await _repository.markResolved(alert.id);
    await _refresh();
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/home/child');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: const Text('Guardian'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<GuardianProtectionAlert>>(
            future: _alertsFuture,
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? const <GuardianProtectionAlert>[];
              final pendingCount = alerts
                  .where((alert) => alert.isQueued)
                  .length;
              final resolvedCount = alerts
                  .where((alert) => alert.isResolved)
                  .length;
              final redCount = alerts.where((alert) => alert.isHighRisk).length;
              final latestAlert = alerts.isEmpty ? null : alerts.first;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _ChildHeroCard(
                    pendingCount: pendingCount,
                    latestAlert: latestAlert,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Needs attention',
                        value: '$pendingCount',
                        tone: _MetricTone.alert,
                        subtitle: pendingCount == 0
                            ? 'No queued follow-up'
                            : 'Child follow-up is waiting',
                      ),
                      _MetricCard(
                        label: 'Red warnings',
                        value: '$redCount',
                        tone: _MetricTone.strong,
                        subtitle: redCount == 0
                            ? 'No high-risk events yet'
                            : 'High-risk payment warnings recorded',
                      ),
                      _MetricCard(
                        label: 'Resolved',
                        value: '$resolvedCount',
                        tone: _MetricTone.calm,
                        subtitle: resolvedCount == 0
                            ? 'Nothing closed yet'
                            : 'Events already followed up',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _PermissionsAndPrivacyCard(
                    onOpen: () => context.push('/disclosure/accessibility'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Protection activity',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (alerts.isEmpty)
                    const _EmptyActivityState()
                  else
                    ...alerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityCard(
                          alert: alert,
                          onOpen: () => _markSeen(alert),
                          onResolve: () => _markResolved(alert),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChildHeroCard extends StatelessWidget {
  const _ChildHeroCard({required this.pendingCount, required this.latestAlert});

  final int pendingCount;
  final GuardianProtectionAlert? latestAlert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = pendingCount == 0
        ? 'Guardian is watching over your parent'
        : 'Guardian needs your attention';
    final subtitle = latestAlert == null
        ? 'Live payment protection is ready. Any stronger red-risk payment event will appear here for family follow-up.'
        : (latestAlert!.body ??
              'A stronger payment-risk event was recorded and queued for family follow-up.');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE7F4F0), Color(0xFFF8F2DD)],
        ),
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
              'Child view',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF0E5E6D),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.tone,
  });

  final String label;
  final String value;
  final String subtitle;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 52) / 2;
    final palette = switch (tone) {
      _MetricTone.alert => (const Color(0xFFFFF0DE), const Color(0xFF8C4D1D)),
      _MetricTone.strong => (const Color(0xFFFFE5E4), const Color(0xFFA12821)),
      _MetricTone.calm => (const Color(0xFFDDF4EA), const Color(0xFF185B4E)),
    };

    return SizedBox(
      width: width < 220 ? double.infinity : width,
      child: Card(
        color: palette.$1,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: palette.$2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: palette.$2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.alert,
    required this.onOpen,
    required this.onResolve,
  });

  final GuardianProtectionAlert alert;
  final VoidCallback onOpen;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final isRed = alert.isHighRisk;
    final badge = switch (alert.status) {
      GuardianProtectionAlertStatus.queued => 'Needs attention',
      GuardianProtectionAlertStatus.seen => 'Seen',
      GuardianProtectionAlertStatus.resolved => 'Resolved',
    };
    final details = <String>[
      if (alert.appLabel != null) alert.appLabel!,
      if (alert.recipientHint != null) 'Recipient ${alert.recipientHint!}',
      if (alert.amountHint != null) 'Amount ${alert.amountHint!}',
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: isRed
                          ? const Color(0xFFFFE5E4)
                          : const Color(0xFFFFF0DE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isRed
                          ? Icons.shield_outlined
                          : Icons.warning_amber_rounded,
                      color: isRed
                          ? const Color(0xFFA12821)
                          : const Color(0xFF8C4D1D),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title ?? 'Payment warning recorded',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.body ??
                              'Guardian recorded a payment-protection event for family follow-up.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (alert.reason != null) ...[
                const SizedBox(height: 12),
                Text(
                  alert.reason!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isRed
                        ? const Color(0xFFA12821)
                        : const Color(0xFF8C4D1D),
                  ),
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  details.join(' | '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusBadge(label: badge, tone: alert.status),
                  Text(
                    _formatTime(alert.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!alert.isResolved)
                    OutlinedButton(
                      onPressed: onResolve,
                      child: const Text('Mark resolved'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final GuardianProtectionAlertStatus tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      GuardianProtectionAlertStatus.queued => (
        const Color(0xFFFFE5E4),
        const Color(0xFFA12821),
      ),
      GuardianProtectionAlertStatus.seen => (
        const Color(0xFFFFF0DE),
        const Color(0xFF8C4D1D),
      ),
      GuardianProtectionAlertStatus.resolved => (
        const Color(0xFFDDF4EA),
        const Color(0xFF185B4E),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: palette.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF3F5F7),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No follow-up alerts yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              'When Guardian notices something that looks suspicious in a stronger red-risk payment flow, the family follow-up event will appear here.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

enum _MetricTone { alert, strong, calm }

class _PermissionsAndPrivacyCard extends StatelessWidget {
  const _PermissionsAndPrivacyCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE7F0FB),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5E6D),
                  borderRadius: BorderRadius.circular(14),
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
                      'Permissions and privacy',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review what Guardian sees on the parent device, why, and how to turn off the Accessibility permission.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
