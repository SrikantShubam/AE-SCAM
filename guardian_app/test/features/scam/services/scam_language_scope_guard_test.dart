import 'package:guardian/features/scam/services/scam_language_scope_guard.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes locale language tags to language code', () {
    expect(ScamLanguageScopeGuard.normalizeLanguageTag('en-IN'), 'en');
    expect(ScamLanguageScopeGuard.normalizeLanguageTag('hi_IN'), 'hi');
    expect(ScamLanguageScopeGuard.normalizeLanguageTag('EN'), 'en');
    expect(ScamLanguageScopeGuard.normalizeLanguageTag(''), 'en');
  });

  test('supports scam template detection only for english locales', () {
    expect(ScamLanguageScopeGuard.supportsScamTemplateDetection('en'), isTrue);
    expect(ScamLanguageScopeGuard.supportsScamTemplateDetection('en-US'), isTrue);
    expect(ScamLanguageScopeGuard.supportsScamTemplateDetection('hi-IN'), isFalse);
    expect(ScamLanguageScopeGuard.supportsScamTemplateDetection('fr-FR'), isFalse);
  });
}
