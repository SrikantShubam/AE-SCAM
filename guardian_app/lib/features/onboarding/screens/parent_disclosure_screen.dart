import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../protection/payment_protection_bridge.dart';
import '../widgets/disclosure_bullet.dart';

class ParentDisclosureScreen extends StatefulWidget {
  const ParentDisclosureScreen({super.key});

  @override
  State<ParentDisclosureScreen> createState() => _ParentDisclosureScreenState();
}

class _ParentDisclosureScreenState extends State<ParentDisclosureScreen>
    with WidgetsBindingObserver {
  bool _serviceEnabled = false;
  bool _checkingPermission = true;
  bool _openingSettings = false;
  bool _awaitingSettingsReturn = false;
  bool _navigatedAfterEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState(autoAdvance: _awaitingSettingsReturn);
    }
  }

  Future<void> _refreshPermissionState({bool autoAdvance = false}) async {
    final isEnabled =
        await PaymentProtectionBridge.isAccessibilityServiceEnabled();
    if (!mounted) {
      return;
    }

    setState(() {
      _serviceEnabled = isEnabled;
      _checkingPermission = false;
      if (isEnabled) {
        _awaitingSettingsReturn = false;
      }
    });

    if (autoAdvance && isEnabled && !_navigatedAfterEnable) {
      _navigatedAfterEnable = true;
      _completeStep(showReadyMessage: true);
    }
  }

  Future<void> _openAccessibilitySettings() async {
    setState(() {
      _openingSettings = true;
      _awaitingSettingsReturn = true;
    });

    try {
      await PaymentProtectionBridge.openAccessibilitySettings();
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _openingSettings = false;
        _awaitingSettingsReturn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not open Android settings yet.'),
        ),
      );
      return;
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _openingSettings = false;
        _awaitingSettingsReturn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not open settings.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _openingSettings = false;
    });
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/onboarding/role-select');
  }

  void _completeStep({bool showReadyMessage = false}) {
    if (showReadyMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live payment protection is ready. Let\'s finish setup.',
          ),
        ),
      );
    }
    context.go('/onboarding/battery-optimization');
  }

  Future<void> _skipStep() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Skip live payment protection?'),
          content: const Text(
            'Without the Accessibility permission, Guardian cannot warn you on real payment screens. You will still get manual payment checks and family follow-up. You can turn live payment protection on later from Permissions and privacy in Guardian.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Skip for now'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      context.go('/onboarding/battery-optimization');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: const Text('Guardian'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Step 3 of 5',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF0E5E6D),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _SetupStatusCard(
              checkingPermission: _checkingPermission,
              serviceEnabled: _serviceEnabled,
              awaitingSettingsReturn: _awaitingSettingsReturn,
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.shield_outlined,
              size: 56,
              color: Color(0xFF0E5E6D),
            ),
            const SizedBox(height: 16),
            Text(
              'Guardian needs one permission',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A323C),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This phone needs Accessibility permission so Guardian can notice a payment screen and ask you to pause before money is sent.',
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
              child: const Column(
                children: [
                  DisclosureBullet(
                    text: 'Sees the amount and who you\'re sending to',
                  ),
                  SizedBox(height: 12),
                  DisclosureBullet(
                    text:
                        'Never sends money or presses any button for you, and does not read your messages',
                  ),
                  SizedBox(height: 12),
                  DisclosureBullet(
                    text: 'You can turn it off any time in Android settings',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/disclosure/accessibility'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF0E5E6D)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'See exactly what Guardian can and cannot see →',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF0E5E6D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _serviceEnabled || _openingSettings
                    ? (_serviceEnabled ? () => _completeStep() : null)
                    : _openAccessibilitySettings,
                child: Text(
                  _serviceEnabled
                      ? 'Continue'
                      : 'Open Android Accessibility settings',
                ),
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _awaitingSettingsReturn
                  ? SizedBox(
                      key: const ValueKey('check-again'),
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _checkingPermission
                            ? null
                            : () => _refreshPermissionState(),
                        child: const Text('Check again'),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('check-again-hidden')),
            ),
            if (_awaitingSettingsReturn) const SizedBox(height: 12),
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

class _SetupStatusCard extends StatelessWidget {
  const _SetupStatusCard({
    required this.checkingPermission,
    required this.serviceEnabled,
    required this.awaitingSettingsReturn,
  });

  final bool checkingPermission;
  final bool serviceEnabled;
  final bool awaitingSettingsReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (title, body, accent, icon) = checkingPermission
        ? (
            'Checking your phone',
            'Guardian is checking whether the Accessibility permission is already on.',
            const Color(0xFFE7F0FB),
            Icons.hourglass_top_rounded,
          )
        : serviceEnabled
        ? (
            'Live payment protection is on',
            'Guardian can now review a payment screen and warn before money is sent.',
            const Color(0xFFDDF4EA),
            Icons.verified_user_outlined,
          )
        : awaitingSettingsReturn
        ? (
            'Return after Android settings',
            'Turn on the Accessibility permission for Guardian, then come back here.',
            const Color(0xFFE7F0FB),
            Icons.settings_accessibility_outlined,
          )
        : (
            'Live payment protection is off',
            'Open Android Accessibility settings to continue setup on this phone.',
            const Color(0xFFFFF0DE),
            Icons.lock_outline_rounded,
          );

    return Card(
      color: accent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyLarge),
            if (checkingPermission) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
