import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstPaymentCheckScreen extends StatelessWidget {
  const FirstPaymentCheckScreen({super.key});

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('payment_protection_setup_complete', true);
    final userRole = prefs.getString('user_role') ?? 'child';
    if (!context.mounted) return;
    if (userRole == 'parent') {
      context.go('/home/parent');
    } else {
      context.go('/home/child');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step dots — step 4 active
              Row(
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == 3 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E5E6D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const Spacer(),
              // Success mark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF4EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF0E5E6D),
                  size: 44,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "Guardian is ready.",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Live payment protection will show a warning on the payment screen before money is sent. If you skipped that permission, manual payment checks still work from inside the app.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F6F76),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medicine reminders',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0A323C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reminders may be up to 15 minutes late on some phones to save battery.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF5F6F76),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () => _finishOnboarding(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E5E6D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Go to Guardian',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
