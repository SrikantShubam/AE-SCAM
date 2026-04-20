import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../protection/models/protection_alert.dart';
import '../providers/child_dashboard_provider.dart';

class ChildProtectionActivitySection extends ConsumerWidget {
  const ChildProtectionActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(childProtectionAlertsProvider);

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
            'Payment protection activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This stays inside the child dashboard as a family safety section.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5F6F76),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          alertsAsync.when(
            data: (alerts) {
              if (alerts.isEmpty) {
                return const _EmptyProtectionState();
              }
              return Column(
                children: alerts
                    .map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProtectionAlertTile(alert: alert),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const _LoadingProtectionState(),
            error: (_, __) => const _ErrorProtectionState(),
          ),
        ],
      ),
    );
  }
}

class _ProtectionAlertTile extends StatelessWidget {
  const _ProtectionAlertTile({required this.alert});

  final GuardianProtectionAlert alert;

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRed ? const Color(0xFFFFE5E4) : const Color(0xFFFFF0DE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: badge),
              _Badge(
                label: isRed ? 'High risk' : 'Review needed',
                color: isRed ? const Color(0xFFFFD0CE) : const Color(0xFFFFE3C4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title ?? 'Payment warning recorded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0A323C),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            alert.body ??
                'Guardian recorded a payment-protection event for family follow-up.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF29434A),
              height: 1.45,
            ),
          ),
          if (alert.reason != null) ...[
            const SizedBox(height: 10),
            Text(
              alert.reason!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isRed ? const Color(0xFFA12821) : const Color(0xFF8C4D1D),
                height: 1.45,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              details.join(' | '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5F6F76),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.72),
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

class _EmptyProtectionState extends StatelessWidget {
  const _EmptyProtectionState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'No recent payment protection alerts yet.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF29434A),
          height: 1.45,
        ),
      ),
    );
  }
}

class _LoadingProtectionState extends StatelessWidget {
  const _LoadingProtectionState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'Loading payment protection activity...',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF29434A),
          height: 1.45,
        ),
      ),
    );
  }
}

class _ErrorProtectionState extends StatelessWidget {
  const _ErrorProtectionState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'Payment protection activity could not load yet.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF29434A),
          height: 1.45,
        ),
      ),
    );
  }
}
