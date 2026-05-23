import 'package:flutter/material.dart';

import '../../medication/models/medication_dose_event.dart';
import '../services/diagnostics_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  late Future<DiagnosticsSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = DiagnosticsService().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field diagnostics')),
      body: FutureBuilder<DiagnosticsSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv('Accessibility service', data.accessibilityEnabled ? 'enabled' : 'disabled'),
              _kv(
                'Notification listener',
                data.notificationListenerEnabled ? 'enabled' : 'disabled',
              ),
              _kv('Firebase connectivity', data.firebaseConnectivityState),
              _kv('pair_id', data.pairId ?? 'unknown'),
              _kv('emergency_disabled', '${data.emergencyDisabled}'),
              _kv('last_fcm_token', data.lastFcmToken ?? 'unknown'),
              const SizedBox(height: 12),
              _sectionTitle('Accessibility events (last 20)'),
              ...data.accessibilityEvents.map((event) => _jsonLine(event)),
              const SizedBox(height: 12),
              _sectionTitle('Notification events (last 20)'),
              ...data.notificationEvents.map((event) => _jsonLine(event)),
              const SizedBox(height: 12),
              _sectionTitle('Medication events (last 20)'),
              ...data.medicationEvents.map(_medicationLine),
              const SizedBox(height: 12),
              _sectionTitle('Safe Browsing'),
              _kv('Cache hit count', '${data.safeBrowsingHitCount}'),
              ...data.safeBrowsingRefreshTimestamps.map(
                (ms) => _kv(
                  'Refresh',
                  DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$key: $value'),
    );
  }

  Widget _jsonLine(Map<String, dynamic> value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(value.toString()),
    );
  }

  Widget _medicationLine(MedicationDoseEvent event) {
    final fired = event.reminderSentAt != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'scheduled=${event.scheduledAt.toIso8601String()} fired=$fired acknowledged_at=${event.actedAt?.toIso8601String() ?? '-'} status=${event.status.name}',
      ),
    );
  }
}
