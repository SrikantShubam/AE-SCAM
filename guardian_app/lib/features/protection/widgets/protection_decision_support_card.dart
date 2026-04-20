import 'package:flutter/material.dart';

import '../models/payment_protection_snapshot.dart';

class ProtectionDecisionSupportCard extends StatefulWidget {
  const ProtectionDecisionSupportCard({
    super.key,
    required this.snapshot,
  });

  final PaymentProtectionSnapshot snapshot;

  @override
  State<ProtectionDecisionSupportCard> createState() =>
      _ProtectionDecisionSupportCardState();
}

class _ProtectionDecisionSupportCardState
    extends State<ProtectionDecisionSupportCard> {
  late final List<bool?> _answers;

  List<String> get _questions {
    final recipient = widget.snapshot.detectedRecipientHint;
    final amount = widget.snapshot.detectedAmountHint;

    return [
      recipient == null || recipient.isEmpty
          ? 'Do you personally know the person asking for money?'
          : 'Do you personally know $recipient?',
      amount == null || amount.isEmpty
          ? 'Were you expecting to send money today?'
          : 'Were you expecting to send $amount today?',
      'Has anyone asked you to hurry, keep this secret, or share a code?',
    ];
  }

  @override
  void initState() {
    super.initState();
    _answers = List<bool?>.filled(3, null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recommendation = _buildRecommendation();

    return Card(
      color: const Color(0xFFF7F3EA),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick yes or no check',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Answer these before you decide. If even one answer is no, step back and call family or the person directly using a number you trust.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < _questions.length; index++) ...[
              _QuestionRow(
                question: _questions[index],
                answer: _answers[index],
                onSelect: (answer) {
                  setState(() {
                    _answers[index] = answer;
                  });
                },
              ),
              if (index < _questions.length - 1) const SizedBox(height: 16),
            ],
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: recommendation.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                recommendation.message,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: recommendation.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _Recommendation _buildRecommendation() {
    final anyNo = _answers.contains(false);
    final answeredCount = _answers.whereType<bool>().length;
    final allYes = answeredCount == _answers.length && _answers.every((answer) => answer == true);

    if (anyNo) {
      if (widget.snapshot.isRed) {
        return const _Recommendation(
          message:
              'Stop now. Choose the safe option, leave the payment screen, and call family or the person directly using a number you trust.',
          background: Color(0xFFF8DADA),
          foreground: Color(0xFF7A1E1E),
        );
      }

      return const _Recommendation(
        message:
            'This payment needs another look. Back out, wait a moment, and speak to family or the person directly before you send money.',
        background: Color(0xFFFFE6C7),
        foreground: Color(0xFF8C4D1D),
      );
    }

    if (allYes) {
      return const _Recommendation(
        message:
            'This feels more expected. Still check the amount and the name carefully before you continue.',
        background: Color(0xFFDDF4EA),
        foreground: Color(0xFF185B4E),
      );
    }

    return const _Recommendation(
      message:
          'Finish the quick check before deciding. Guardian is trying to slow the moment down, not rush you.',
      background: Color(0xFFE7F0FB),
      foreground: Color(0xFF214C69),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.answer,
    required this.onSelect,
  });

  final String question;
  final bool? answer;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      answer == true ? const Color(0xFF0E5E6D) : null,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => onSelect(true),
                child: const Text('Yes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(
                    color: answer == false
                        ? const Color(0xFF8C4D1D)
                        : const Color(0xFF9EB0B7),
                    width: answer == false ? 2 : 1,
                  ),
                ),
                onPressed: () => onSelect(false),
                child: const Text('No'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Recommendation {
  const _Recommendation({
    required this.message,
    required this.background,
    required this.foreground,
  });

  final String message;
  final Color background;
  final Color foreground;
}
