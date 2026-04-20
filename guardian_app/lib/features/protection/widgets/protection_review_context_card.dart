import 'package:flutter/material.dart';

import '../models/payment_protection_snapshot.dart';

class ProtectionReviewContextCard extends StatelessWidget {
  const ProtectionReviewContextCard({
    super.key,
    required this.snapshot,
  });

  final PaymentProtectionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasContext = snapshot.detectedAmountHint != null ||
        snapshot.detectedRecipientHint != null ||
        snapshot.detectedUpiIdHint != null ||
        snapshot.lastMonitoredAppLabel != null;

    if (!hasContext) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              snapshot.isWarning
                  ? 'Payment details on screen'
                  : 'What Guardian can see',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              snapshot.isWarning
                  ? 'Take one calm look at these details before you decide.'
                  : 'Guardian stays quiet until a payment screen appears. These are the details it may use to protect the elder user.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (snapshot.lastMonitoredAppLabel != null)
                  _ContextPill(
                    label: 'App',
                    value: snapshot.lastMonitoredAppLabel!,
                  ),
                if (snapshot.detectedAmountHint != null)
                  _ContextPill(
                    label: 'Amount',
                    value: snapshot.detectedAmountHint!,
                  ),
                if (snapshot.detectedRecipientHint != null)
                  _ContextPill(
                    label: 'Recipient',
                    value: snapshot.detectedRecipientHint!,
                  ),
                if (snapshot.detectedUpiIdHint != null)
                  _ContextPill(
                    label: 'UPI ID',
                    value: snapshot.detectedUpiIdHint!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0xFF48626B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
