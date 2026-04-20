import 'package:guardian/features/scam/models/scam_match_result.dart';
import 'package:test/test.dart';

void main() {
  test('confirmedUrlThreat returns alert severity and confirmed-threat reason', () {
    final result = ScamMatchResult.confirmedUrlThreat();

    expect(result.matched, isTrue);
    expect(result.category, 'confirmed_url_threat');
    expect(result.severity, ScamSeverity.alert);
    expect(result.reason, contains('known harmful link'));
    expect(result.reason, contains("please check with your caregiver"));
  });
}
