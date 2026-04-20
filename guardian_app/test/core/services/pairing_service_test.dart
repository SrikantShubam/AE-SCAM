import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/pairing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('generatePairingCode returns 6 chars from allowed alphabet only', () {
    const allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    for (var i = 0; i < 500; i++) {
      final code = PairingService.generatePairingCode();
      expect(code.length, 6);
      for (final ch in code.split('')) {
        expect(allowed.contains(ch), isTrue, reason: 'Unexpected char: $ch');
      }
      expect(code.contains('I'), isFalse);
      expect(code.contains('O'), isFalse);
      expect(code.contains('0'), isFalse);
      expect(code.contains('1'), isFalse);
    }
  });

  test('sanitizeCode strips separators and normalizes case', () {
    final service = PairingService();
    expect(service.sanitizeCode(' ab-23 cd '), 'AB23CD');
  });
}
