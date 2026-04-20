class ScamSuspicionHeuristicResult {
  const ScamSuspicionHeuristicResult({
    required this.triggered,
    required this.matchedSignals,
    required this.detectedUrls,
  });

  final bool triggered;
  final List<String> matchedSignals;
  final List<String> detectedUrls;
}

class ScamSuspicionHeuristic {
  const ScamSuspicionHeuristic._();

  static final RegExp _urlPattern = RegExp(
    r'(?:(?:https?:\/\/)[^\s]+)|(?:\b(?:bit\.ly|tinyurl\.com|t\.co|shorturl(?:\.at|\.com)?)\/?[^\s]*)',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?91[-\s]?)?[6-9]\d{9}\b',
    caseSensitive: false,
  );
  static final RegExp _tollFreePattern = RegExp(
    r'\b(?:1800|1860)[-\s]?\d{3}[-\s]?\d{3,4}\b',
    caseSensitive: false,
  );
  static final RegExp _amountPattern = RegExp(r'\b\d{1,3}(?:,\d{3})+\b');
  static final RegExp _upiPattern = RegExp(
    r'\b[a-z0-9._-]+@[a-z]+\b',
    caseSensitive: false,
  );
  static final RegExp _withinTimePattern = RegExp(
    r'within\s+\d+\s+(?:hours?|minutes?)',
    caseSensitive: false,
  );

  static ScamSuspicionHeuristicResult evaluate({
    required String text,
    required bool senderInContacts,
  }) {
    final normalized = text.toLowerCase();
    final urls = _extractUrls(text);
    final hasUrl = urls.isNotEmpty;
    final hasPhone =
        _phonePattern.hasMatch(text) || _tollFreePattern.hasMatch(text);
    final hasMoney =
        text.contains('₹') ||
        _containsAny(normalized, const <String>['rs', 'inr', 'rupees']) ||
        _amountPattern.hasMatch(text) ||
        _upiPattern.hasMatch(text);
    final hasUrgency =
        _containsAny(normalized, const <String>[
          'urgent',
          'immediately',
          'expires',
          'blocked',
          'suspended',
          'last chance',
        ]) ||
        _withinTimePattern.hasMatch(text);
    final hasAuthWords = _containsAny(normalized, const <String>[
      'otp',
      'kyc',
      'verify',
      'account',
      'refund',
      'reward',
      'lottery',
      'prize',
      'cashback',
      'customer care',
      'helpline',
    ]);

    final signals = <String>[
      if (hasUrl) 'has_url',
      if (hasPhone) 'has_phone',
      if (hasMoney) 'has_money',
      if (hasUrgency) 'has_urgency',
      if (hasAuthWords) 'has_auth_words',
    ];

    final triggered = signals.length >= 2 || (!senderInContacts && hasUrl);
    return ScamSuspicionHeuristicResult(
      triggered: triggered,
      matchedSignals: signals,
      detectedUrls: urls,
    );
  }

  static List<String> _extractUrls(String text) {
    final urls = <String>{};
    for (final match in _urlPattern.allMatches(text)) {
      final value = match.group(0)?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      urls.add(value);
    }
    return urls.toList(growable: false);
  }

  static bool _containsAny(String text, List<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) {
        return true;
      }
    }
    return false;
  }
}
