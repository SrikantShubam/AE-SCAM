import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/onboarding_flow_shell.dart';
import '../config/consent_content.dart';
import '../providers/consent_provider.dart';
import 'accessibility_disclosure_screen.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.consentType = ConsentType.dpdpa});

  final ConsentType consentType;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _checkboxChecked = false;
  bool _handledExistingConsent = false;
  bool _saving = false;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/onboarding/welcome');
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AccessibilityDisclosureScreen.privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the privacy policy in your browser.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ConsentContent.forConsentType(widget.consentType);
    final consentAsync = ref.watch(consentProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _handleBack),
        title: const Text('Guardian'),
      ),
      body: consentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(consentProvider),
        ),
        data: (record) {
          final hasCurrentConsent = record.hasConsentFor(
            content.consentVersion,
          );
          if (hasCurrentConsent && !_handledExistingConsent) {
            _handledExistingConsent = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              } else {
                setState(() {
                  _checkboxChecked = true;
                });
              }
            });
          }

          return OnboardingFlowShell(
            stepLabel: 'Step 1 of 4',
            title: 'A few things before we start',
            subtitle: '',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Single compact summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(
                        icon: Icons.lock_outline_rounded,
                        text:
                            'Guardian only reads payment screens you choose to protect — nothing else on this phone.',
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(
                        icon: Icons.block_rounded,
                        text:
                            'Guardian never sends money, does not read your messages, and does not share data with advertisers.',
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(
                        icon: Icons.settings_outlined,
                        text:
                            'You can turn off any permission at any time from Android settings.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Privacy policy link — prominent, not a footnote
                InkWell(
                  onTap: _openPrivacyPolicy,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: Color(0xFF0E5E6D),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Read the full privacy policy',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF0E5E6D),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  checked: _checkboxChecked || hasCurrentConsent,
                  container: true,
                  child: CheckboxListTile(
                    value: _checkboxChecked || hasCurrentConsent,
                    onChanged: hasCurrentConsent
                        ? null
                        : (value) =>
                              setState(() => _checkboxChecked = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      content.checkboxLabel,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        (_checkboxChecked || hasCurrentConsent) && !_saving
                        ? () => _continue(content)
                        : null,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(content.continueLabel),
                  ),
                ),
                if (hasCurrentConsent) ...[
                  const SizedBox(height: 12),
                  _AlreadyRecordedBanner(content: content),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _continue(ConsentContent content) async {
    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(consentProvider.notifier)
          .recordConsent(consentVersion: content.consentVersion);

      if (!mounted) {
        return;
      }

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/onboarding/role-select');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(icon, size: 22, color: const Color(0xFF0E5E6D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _AlreadyRecordedBanner extends StatelessWidget {
  const _AlreadyRecordedBanner({required this.content});

  final ConsentContent content;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.alreadyRecordedLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              content.alreadyRecordedSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load consent state.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
