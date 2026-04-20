enum ThreatVerdict { unknown, safe, phishing, malware, unwanted }

class UrlReputationChecker {
  const UrlReputationChecker();

  Future<ThreatVerdict> check(String url) async {
    if (url.trim().isEmpty) {
      return ThreatVerdict.unknown;
    }
    // WO-URL-01 will provide the Safe Browsing-backed implementation.
    return ThreatVerdict.unknown;
  }
}
