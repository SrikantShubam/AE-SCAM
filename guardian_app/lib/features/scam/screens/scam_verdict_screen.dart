import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/scam_match_result.dart';

class ScamVerdictRouteData {
  const ScamVerdictRouteData({required this.sharedText, required this.result});

  final String sharedText;
  final ScamMatchResult result;
}

class ScamVerdictScreen extends StatelessWidget {
  const ScamVerdictScreen({super.key, required this.data});

  final ScamVerdictRouteData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityLabel = _severityLabel(data.result.severity);

    return Scaffold(
      appBar: AppBar(title: const Text('Scam check result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Shared message',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(data.sharedText, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Guardian verdict',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Chip(label: Text(severityLabel)),
                    const SizedBox(height: 10),
                    Text(data.result.reason, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _callCaregiver(context),
              child: const Text('Call caregiver'),
            ),
          ],
        ),
      ),
    );
  }

  String _severityLabel(ScamSeverity severity) {
    return switch (severity) {
      ScamSeverity.alert => 'Alert',
      ScamSeverity.warn => 'Warn',
      ScamSeverity.info => 'Info',
    };
  }

  Future<void> _callCaregiver(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getString('caregiver_phone')?.trim() ?? '';
    if (number.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No caregiver phone number is saved yet. Please check with your caregiver.',
          ),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: number);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the dialer right now.')),
    );
  }
}
