import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/pairing_service.dart';

class ParentPairingScreen extends StatefulWidget {
  ParentPairingScreen({super.key, PairingService? pairingService})
    : pairingService = pairingService ?? PairingService();

  final PairingService pairingService;

  @override
  State<ParentPairingScreen> createState() => _ParentPairingScreenState();
}

class _ParentPairingScreenState extends State<ParentPairingScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadPendingCode();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() {
      _submitting = true;
      _message = null;
    });

    final result = await widget.pairingService.claimParentCode(_controller.text);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      _success = result.isSuccess;
      _message = result.message;
    });

    if (result.isSuccess) {
      context.go('/onboarding/parent-disclosure');
    }
  }

  Future<void> _loadPendingCode() async {
    final pending = await widget.pairingService.pendingCode();
    if (!mounted || pending == null || pending.isEmpty) {
      return;
    }
    _controller.text = pending;
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
                'Enter the pairing code',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF0A323C),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use the 6-character code your caregiver shared. Guardian will save it if you need to retry later.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5F6F76),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                maxLength: PairingService.pairingCodeLength,
                decoration: const InputDecoration(
                  labelText: 'Pairing code',
                  hintText: 'AB23CD',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _success ? const Color(0xFF0E5E6D) : Colors.orange.shade900,
                    height: 1.4,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _submitting ? null : _claim,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0E5E6D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_submitting ? 'Checking code...' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
