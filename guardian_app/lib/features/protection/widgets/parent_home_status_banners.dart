import 'package:flutter/material.dart';

import '../models/payment_protection_snapshot.dart';

class ParentHomeStatusBanners extends StatelessWidget {
  const ParentHomeStatusBanners({required this.snapshot, super.key});

  final PaymentProtectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (!snapshot.accessibilityHealthEnabled) ...[
        const _AccessibilityHealthBanner(),
        if (snapshot.emergencyDisabled) const SizedBox(height: 20),
      ],
      if (snapshot.emergencyDisabled) const _EmergencyDisableBanner(),
    ];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
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

class _EmergencyDisableBanner extends StatelessWidget {
  const _EmergencyDisableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFE2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        'Protection paused by caregiver',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF7A1F16),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
