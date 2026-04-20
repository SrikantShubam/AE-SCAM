import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'scam_parent_warning_notifier.dart';

class LocalScamParentWarningNotifier implements ScamParentWarningNotifier {
  LocalScamParentWarningNotifier({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'guardian_scam_alerts';
  static const String _channelName = 'Guardian Scam Alerts';
  static const String _channelDescription =
      'Immediate alerts when Guardian detects suspicious scam threats.';
  static const String _title = 'Guardian thinks this message may be a scam';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> showConfirmedThreatWarning({required String messageBody}) async {
    try {
      await _ensureInitialized();
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: _title,
        body: _buildBody(messageBody),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
      );
    } catch (_) {
      // Notification posting is best-effort and should not block scam handling.
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  String _buildBody(String messageBody) {
    final normalized = messageBody.trim();
    if (normalized.isEmpty) {
      return "This message looks suspicious. We're not sure, so please check with your caregiver.";
    }

    const maxSnippetLength = 90;
    final snippet = normalized.length <= maxSnippetLength
        ? normalized
        : normalized.substring(0, maxSnippetLength);
    return "This message looks suspicious: \"$snippet\". We're not sure, so please check with your caregiver.";
  }
}
