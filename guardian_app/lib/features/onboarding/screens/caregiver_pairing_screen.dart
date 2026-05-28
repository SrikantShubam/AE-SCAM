import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/pairing_service.dart';

class CaregiverPairingScreen extends StatefulWidget {
  CaregiverPairingScreen({super.key, PairingService? pairingService})
    : pairingService = pairingService ?? PairingService();

  final PairingService pairingService;

  @override
  State<CaregiverPairingScreen> createState() => _CaregiverPairingScreenState();
}

class _CaregiverPairingScreenState extends State<CaregiverPairingScreen> {
  bool _loading = false;
  PairingDraftResult? _result;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() {
      _loading = true;
    });
    final result = await widget.pairingService.createCaregiverCode();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  Future<void> _finishCaregiverOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('payment_protection_setup_complete', true);
    if (!mounted) {
      return;
    }
    context.go('/home/child');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = _result?.isSuccess ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == 2 ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= 2
                          ? const Color(0xFF0E5E6D)
                          : const Color(0xFFDDE3E7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              Text(
                'Share this pairing code',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tell your parent this code or send it by message. It stays active for 24 hours.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F6F76),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x120A323C),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : success
                      ? _SuccessBody(result: _result!)
                      : _FailureBody(
                          message:
                              _result?.message ??
                              'Guardian could not create the pairing code yet.',
                          onRetry: _generateCode,
                        ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: success ? _finishCaregiverOnboarding : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E5E6D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.result});

  final PairingDraftResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active code',
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5F6F76),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SelectableText(
          result.code ?? '',
          style: theme.textTheme.displaySmall?.copyWith(
            color: const Color(0xFF0A323C),
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pair ID: ${result.pairId}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF455B63),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Expires ${_formatExpiry(result.expiresAt)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF455B63),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'If your parent is offline right now, they can still type the code and retry once they reconnect.',
        ),
      ],
    );
  }

  String _formatExpiry(DateTime? value) {
    if (value == null) {
      return 'in 24 hours';
    }
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return 'by ${value.day}/${value.month} at $hour:$minute $suffix';
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.wifi_tethering_error_rounded, color: Colors.orange.shade700, size: 36),
        const SizedBox(height: 16),
        Text(
          'Pairing is not ready yet',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF0A323C),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF455B63),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}
