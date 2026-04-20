import 'package:flutter/material.dart';

class DisclosureBullet extends StatelessWidget {
  const DisclosureBullet({
    super.key,
    required this.text,
    this.icon = Icons.check_circle_outline,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: text,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
