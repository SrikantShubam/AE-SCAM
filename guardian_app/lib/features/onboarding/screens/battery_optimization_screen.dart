import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/battery_optimization_bridge.dart';

class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() =>
      _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  static const _completedKey = 'battery_optimization_step_completed';
  static const _skippedKey = 'battery_optimization_step_skipped';
  bool _openingSettings = false;

  Future<void> _markCompletedAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    await prefs.setBool(_skippedKey, false);
    if (!mounted) {
      return;
    }
    context.go('/onboarding/first-check');
  }

  Future<void> _skipStep() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, false);
    await prefs.setBool(_skippedKey, true);
    if (!mounted) {
      return;
    }
    context.go('/onboarding/first-check');
  }

  Future<void> _openBatterySettings() async {
    setState(() {
      _openingSettings = true;
    });

    final opened =
        await BatteryOptimizationBridge.openBatteryOptimizationSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      _openingSettings = false;
    });

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not open battery settings yet.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Guardian')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Step 4 of 5',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF0E5E6D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keep medicine reminders running',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A323C),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Some phones stop reminders to save battery. Allow Guardian to run so we can remind your parent on time.',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                height: 1.45,
                color: const Color(0xFF29434A),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What this does',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A323C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guardian opens your phone\'s battery settings page so you can allow background reminder delivery.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF455B63),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _openingSettings ? null : _openBatterySettings,
                child: Text(
                  _openingSettings
                      ? 'Opening Android battery settings...'
                      : 'Open battery optimization settings',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _markCompletedAndContinue,
                child: const Text('I completed this'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: TextButton(
                onPressed: _skipStep,
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
