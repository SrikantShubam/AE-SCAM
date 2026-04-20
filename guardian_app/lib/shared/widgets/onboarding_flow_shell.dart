import 'package:flutter/material.dart';

class OnboardingFlowShell extends StatelessWidget {
  const OnboardingFlowShell({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget child;

  ({int current, int total})? _parseStepLabel() {
    final match = RegExp(r'Step\s+(\d+)\s+of\s+(\d+)').firstMatch(stepLabel);
    if (match == null) return null;
    final current = int.tryParse(match.group(1) ?? '');
    final total = int.tryParse(match.group(2) ?? '');
    if (current == null || total == null || total <= 0) return null;
    return (current: current, total: total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepInfo = _parseStepLabel();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Minimal step progress — dots only, no text chrome
            if (stepInfo != null) ...[
              Row(
                children: List.generate(stepInfo.total, (i) {
                  final active = i < stepInfo.current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == stepInfo.current - 1 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF0E5E6D)
                          : const Color(0xFFDDE3E7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
            ],
            // Screen heading
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF0A323C),
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F6F76),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}
