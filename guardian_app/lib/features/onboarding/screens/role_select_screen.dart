import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    if (!context.mounted) return;
    if (role == 'parent') {
      context.go('/onboarding/pairing/enter');
    } else {
      context.go('/onboarding/pairing/generate');
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
              // Minimal step dots
              Row(
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == 1 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= 1
                          ? const Color(0xFF0E5E6D)
                          : const Color(0xFFDDE3E7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Text(
                'Whose phone is this?',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick the option that fits this device.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F6F76),
                ),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.person_outline,
                title: "The parent's phone",
                description:
                    'Connect this phone to a caregiver with a pairing code, then finish the protection setup.',
                onTap: () => _selectRole(context, 'parent'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.family_restroom_outlined,
                title: 'The child or caregiver phone',
                description:
                    'Create the pairing code, help the parent connect, and receive family follow-up alerts.',
                onTap: () => _selectRole(context, 'child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F4F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF0E5E6D), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0A323C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5F6F76),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF5F6F76),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
