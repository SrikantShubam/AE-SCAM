import 'dart:async';

import 'package:flutter/material.dart';

class ProtectionCooldownGate extends StatefulWidget {
  const ProtectionCooldownGate({
    super.key,
    required this.seconds,
    required this.proceedLabel,
    required this.onProceed,
  });

  final int seconds;
  final String proceedLabel;
  final VoidCallback onProceed;

  @override
  State<ProtectionCooldownGate> createState() => _ProtectionCooldownGateState();
}

class _ProtectionCooldownGateState extends State<ProtectionCooldownGate> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ProtectionCooldownGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _remainingSeconds = widget.seconds;
      _timer?.cancel();
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    if (_remainingSeconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
        });
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_remainingSeconds > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8DADA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Continue appears after a short pause',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              _formatClock(_remainingSeconds),
              style: textTheme.displaySmall?.copyWith(
                color: const Color(0xFF7A1E1E),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use this time to check the name, amount, and why the payment is needed.',
              style: textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
      onPressed: widget.onProceed,
      child: Text(widget.proceedLabel),
    );
  }

  String _formatClock(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }
}
