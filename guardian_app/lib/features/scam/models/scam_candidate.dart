class ScamCandidate {
  const ScamCandidate({
    required this.id,
    required this.source,
    required this.textHash,
    required this.text,
    required this.sender,
    required this.signalsMatched,
    required this.urlVerdicts,
    required this.createdAtMs,
    required this.status,
  });

  final String id;
  final String source;
  final String textHash;
  final String text;
  final String? sender;
  final List<String> signalsMatched;
  final List<String> urlVerdicts;
  final int createdAtMs;
  final String status;

  Map<String, Object?> toRemoteMap({required bool includeSensitiveText}) {
    return <String, Object?>{
      'source': source,
      'signals_matched': signalsMatched,
      'url_verdicts': urlVerdicts,
      'message_hash': textHash,
      'text': includeSensitiveText ? text : null,
      'sender': includeSensitiveText ? sender : null,
      'message_preview': includeSensitiveText ? _preview(text) : null,
      'created_at': createdAtMs,
      'status': status,
    };
  }

  String _preview(String value) {
    const maxPreview = 140;
    final normalized = value.trim();
    if (normalized.length <= maxPreview) {
      return normalized;
    }
    return normalized.substring(0, maxPreview);
  }
}
