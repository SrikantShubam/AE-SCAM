enum ScamSeverity { info, warn, alert }

class ScamMatchResult {
  const ScamMatchResult({
    required this.matched,
    required this.templateId,
    required this.category,
    required this.severity,
    required this.reason,
  });

  final bool matched;
  final String? templateId;
  final String? category;
  final ScamSeverity severity;
  final String reason;

  factory ScamMatchResult.unmatched() {
    return const ScamMatchResult(
      matched: false,
      templateId: null,
      category: null,
      severity: ScamSeverity.info,
      reason:
          "This message looks suspicious. We're not sure, so please check with your caregiver.",
    );
  }

  factory ScamMatchResult.confirmedUrlThreat() {
    return const ScamMatchResult(
      matched: true,
      templateId: null,
      category: 'confirmed_url_threat',
      severity: ScamSeverity.alert,
      reason:
          "This message looks suspicious because it contains a known harmful link. We're not sure, so please check with your caregiver.",
    );
  }
}
