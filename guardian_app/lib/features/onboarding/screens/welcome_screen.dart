import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/guardian_brand_mark.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primaryContainer, cs.surface],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -36,
                      right: -20,
                      child: Container(
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF68B7A3,
                          ).withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -14,
                      bottom: 16,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFFD799,
                          ).withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _fadeIn,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.84),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Guided setup in 4 short steps',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF0E5E6D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          const GuardianBrandMark(size: 108),
                          SizedBox(height: screenHeight * 0.03),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              4,
                              (index) => Container(
                                margin: EdgeInsets.only(
                                  right: index == 3 ? 0 : 8,
                                ),
                                width: index == 0 ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFF0E5E6D)
                                      : Colors.white.withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.03),
                          Text(
                            'Guardian',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: const Color(0xFF0E5E6D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Daily support and live payment protection for families caring for elders',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: SlideTransition(
                position: _slideUp,
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.45,
                            physics: const NeverScrollableScrollPhysics(),
                            children: const [
                              _FeaturePill(
                                icon: Icons.medication_outlined,
                                label: 'Medication\nreminders',
                                tint: Color(0xFFE8F5E9),
                                iconColor: Color(0xFF2E7D32),
                              ),
                              _FeaturePill(
                                icon: Icons.shield_outlined,
                                label: 'Payment\nprotection',
                                tint: Color(0xFFE3F2FD),
                                iconColor: Color(0xFF1565C0),
                              ),
                              _FeaturePill(
                                icon: Icons.notifications_active_outlined,
                                label: 'Family\nalerts',
                                tint: Color(0xFFFFF3E0),
                                iconColor: Color(0xFFE65100),
                              ),
                              _FeaturePill(
                                icon: Icons.favorite_outline,
                                label: 'Health\nreadings',
                                tint: Color(0xFFFCE4EC),
                                iconColor: Color(0xFFC62828),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: () => context.go('/onboarding/consent'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0E5E6D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You can still use Guardian without live payment protection. That extra layer is set up a little later.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: iconColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
