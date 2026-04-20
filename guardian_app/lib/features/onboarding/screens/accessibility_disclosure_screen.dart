import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../protection/payment_protection_bridge.dart';
import '../widgets/disclosure_bullet.dart';

/// Standalone, re-enterable Accessibility disclosure surface.
///
/// This screen is required for Google Play AccessibilityService policy
/// compliance. It must be reachable from outside the onboarding flow so users
/// (and Play reviewers) can review what data Guardian accesses, why, and how
/// to revoke it at any time.
///
/// Routed at `/disclosure/accessibility` so it lives outside the onboarding
/// redirect tree.
class AccessibilityDisclosureScreen extends StatefulWidget {
  const AccessibilityDisclosureScreen({super.key});

  static const String privacyPolicyUrl =
      'https://vectorveda.online/guardian-privacy-policy';

  @override
  State<AccessibilityDisclosureScreen> createState() =>
      _AccessibilityDisclosureScreenState();
}

class _AccessibilityDisclosureScreenState
    extends State<AccessibilityDisclosureScreen>
    with WidgetsBindingObserver {
  bool _serviceEnabled = false;
  bool _checkingPermission = true;

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
      _refreshPermissionState();
    }
  }

  Future<void> _refreshPermissionState() async {
    final isEnabled =
        await PaymentProtectionBridge.isAccessibilityServiceEnabled();
    if (!mounted) return;
    setState(() {
      _serviceEnabled = isEnabled;
      _checkingPermission = false;
    });
  }

  Future<void> _openSettings() async {
    try {
      await PaymentProtectionBridge.openAccessibilitySettings();
    } on MissingPluginException {
      _showSnack('Guardian could not open Android settings yet.');
    } on PlatformException catch (error) {
      _showSnack(error.message ?? 'Could not open settings.');
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AccessibilityDisclosureScreen.privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack('Could not open the privacy policy in your browser.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/home/parent');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: const Text('Permissions & privacy'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFFE7F4F0), Color(0xFFF8F2DD)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E5E6D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Accessibility permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How Guardian uses Accessibility',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF0E5E6D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Guardian uses the Android Accessibility Service only to '
                    'protect elderly users from risky payments. You can review '
                    'the details below at any time and manage this permission '
                    'whenever you want.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live status card
            _StatusCard(
              checking: _checkingPermission,
              enabled: _serviceEnabled,
            ),
            const SizedBox(height: 20),

            // What data is accessed
            _SectionCard(
              accent: const Color(0xFFE7F0FB),
              title: 'What data Guardian accesses',
              children: const [
                DisclosureBullet(
                  text:
                      'The package name of the app currently in the foreground, only to know when a supported payment app is open.',
                ),
                SizedBox(height: 12),
                DisclosureBullet(
                  text:
                      'On supported payment screens only: amount, recipient name, UPI ID, and payment note.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // What Guardian never does
            _SectionCard(
              accent: const Color(0xFFFFF0DE),
              title: 'What Guardian never does',
              children: const [
                DisclosureBullet(
                  text:
                      'Guardian does not read your messages, photos, contacts, or any app outside supported payment screens.',
                  icon: Icons.block_rounded,
                ),
                SizedBox(height: 12),
                DisclosureBullet(
                  text:
                      'Guardian never presses pay, never sends money, and never completes a transaction for you.',
                  icon: Icons.block_rounded,
                ),
                SizedBox(height: 12),
                DisclosureBullet(
                  text:
                      'Guardian does not sell, share, or use this data for advertising. Data leaves your device only when needed for an immediate safety check.',
                  icon: Icons.block_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // How to revoke
            _SectionCard(
              accent: const Color(0xFFDDF4EA),
              title: 'How to turn this off',
              children: [
                Text(
                  'This page stays available after setup so you can review what '
                  'Guardian can access and manage the permission any time from '
                  'Android Settings > Accessibility > Guardian. When it is off, '
                  'Guardian still works with manual payment checks and family '
                  'alerts.',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Privacy policy link
            _SectionCard(
              accent: const Color(0xFFF3F5F7),
              title: 'Read the full privacy policy',
              children: [
                Text(
                  'The full privacy policy describes everything Guardian '
                  'collects, how long it is kept, and your rights.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _openPrivacyPolicy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: Color(0xFF0E5E6D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AccessibilityDisclosureScreen.privacyPolicyUrl,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF0E5E6D),
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              height: 56,
                child: FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_accessibility_outlined),
                  label: Text(
                  _serviceEnabled
                      ? 'Manage permission in Android settings'
                      : 'Open Android Accessibility settings',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _checkingPermission ? null : _refreshPermissionState,
                child: const Text('Check status again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.checking, required this.enabled});

  final bool checking;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body, accent, icon) = checking
        ? (
            'Checking device status',
            'Guardian is checking whether the Accessibility permission is currently on.',
            const Color(0xFFE7F0FB),
            Icons.hourglass_top_rounded,
          )
        : enabled
        ? (
            'Live payment protection is active',
            'Guardian can review supported payment screens to warn before money is sent.',
            const Color(0xFFDDF4EA),
            Icons.verified_user_outlined,
          )
        : (
            'Live payment protection is off',
            'Guardian is using manual payment checks only. Live payment protection cannot appear until the permission is turned on.',
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
            if (checking) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.accent,
    required this.title,
    required this.children,
  });

  final Color accent;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: accent,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
