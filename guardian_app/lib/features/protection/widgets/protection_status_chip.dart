import 'package:flutter/material.dart';

import '../models/payment_protection_snapshot.dart';

/// Compact status pill for payment protection state.
/// Used on home surfaces to keep copy + color consistent.
class ProtectionStatusChip extends StatelessWidget {
  const ProtectionStatusChip({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final PaymentProtectionSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final _StatusView view = _buildView(colorScheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: view.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(view.icon, size: compact ? 14 : 16, color: view.foreground),
          const SizedBox(width: 6),
          Text(
            view.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: view.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  _StatusView _buildView(ColorScheme colors) {
    // Accessibility service off or inactive snapshot.
    if (!snapshot.serviceEnabled || snapshot.isInactive) {
      return _StatusView(
        label: 'Setup needed',
        icon: Icons.shield_outlined,
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
      );
    }

    // Active warning (amber / red).
    if (snapshot.isRed) {
      return _StatusView(
        label: 'High-risk warning',
        icon: Icons.warning_amber_rounded,
        background: const Color(0xFFFFE2DD),
        foreground: const Color(0xFF912018),
      );
    }

    if (snapshot.isAmber) {
      return _StatusView(
        label: 'Payment warning',
        icon: Icons.report_gmailerrorred_rounded,
        background: const Color(0xFFFFF4E5),
        foreground: const Color(0xFF8C4D1D),
      );
    }

    // Monitoring quietly.
    return _StatusView(
      label: 'Watching quietly',
      icon: Icons.shield_moon_outlined,
      background: const Color(0xFFDDF4EA),
      foreground: const Color(0xFF185B4E),
    );
  }
}

class _StatusView {
  const _StatusView({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}
