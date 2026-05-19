import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/scam_language_scope_guard.dart';

class ScamLanguageScopeNoticeHost extends StatefulWidget {
  const ScamLanguageScopeNoticeHost({
    required this.child,
    required this.scaffoldMessengerKey,
    super.key,
  });

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  State<ScamLanguageScopeNoticeHost> createState() =>
      _ScamLanguageScopeNoticeHostState();
}

class _ScamLanguageScopeNoticeHostState extends State<ScamLanguageScopeNoticeHost> {
  static const String _englishOnlyNoticeShownKey =
      'guardian_scam_english_only_notice_shown';
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) {
      return;
    }
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNoticeIfNeeded();
    });
  }

  Future<void> _showNoticeIfNeeded() async {
    if (!mounted) {
      return;
    }
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    if (ScamLanguageScopeGuard.supportsScamTemplateDetection(localeTag)) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_englishOnlyNoticeShownKey) ?? false;
    if (alreadyShown) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Guardian scam detection currently supports English only.'),
      ),
    );
    await prefs.setBool(_englishOnlyNoticeShownKey, true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
