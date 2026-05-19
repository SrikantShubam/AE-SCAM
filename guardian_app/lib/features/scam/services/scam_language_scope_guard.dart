class ScamLanguageScopeGuard {
  const ScamLanguageScopeGuard._();

  static String normalizeLanguageTag(String languageTag) {
    final trimmed = languageTag.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return 'en';
    }
    final separatorIndex = trimmed.indexOf(RegExp(r'[-_]'));
    if (separatorIndex <= 0) {
      return trimmed;
    }
    return trimmed.substring(0, separatorIndex);
  }

  static bool supportsScamTemplateDetection(String languageTag) {
    return normalizeLanguageTag(languageTag) == 'en';
  }
}
