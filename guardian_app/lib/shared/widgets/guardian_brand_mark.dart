import 'package:flutter/material.dart';

/// Renders the official Guardian launcher logo as an in-app brand mark.
///
/// The asset comes from `assets/branding/guardian_logo.png`, which is the
/// same artwork shipped as the Android launcher icon and Play Store icon, so
/// the in-app branding stays consistent with what users see on their home
/// screen and in the Play Store listing.
class GuardianBrandMark extends StatelessWidget {
  const GuardianBrandMark({
    super.key,
    this.size = 92,
    this.showHalo = true,
  });

  final double size;
  final bool showHalo;

  static const String _logoAsset = 'assets/branding/guardian_logo.png';

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: const Color(0xFF0A323C),
        boxShadow: <BoxShadow>[
          if (showHalo)
            BoxShadow(
              color: const Color(0xFF68B7A3).withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: 1,
              offset: const Offset(0, 14),
            ),
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          _logoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
