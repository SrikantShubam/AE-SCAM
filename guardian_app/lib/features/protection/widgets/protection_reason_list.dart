import 'package:flutter/material.dart';

class ProtectionReasonList extends StatelessWidget {
  const ProtectionReasonList({
    super.key,
    required this.reasons,
    this.signals = const <String>[],
  });

  final List<String> reasons;
  final List<String> signals;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty && signals.isEmpty) {
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
              'Why Guardian noticed something that looks suspicious',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (reasons.isNotEmpty)
              for (var index = 0; index < reasons.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xFF0E5E6D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(reasons[index], style: textTheme.bodyLarge),
                    ),
                  ],
                ),
                if (index < reasons.length - 1) const SizedBox(height: 12),
              ],
            if (signals.isNotEmpty) ...[
              if (reasons.isNotEmpty) const SizedBox(height: 16),
              Text(
                'Signals noticed on screen',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: signals
                    .map(
                      (signal) => Chip(
                        label: Text(_prettySignal(signal)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _prettySignal(String signal) {
    final cleaned = signal.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (cleaned.isEmpty) {
      return signal;
    }

    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}
