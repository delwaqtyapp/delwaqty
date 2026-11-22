import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/utils/egypt_phone.dart';

void main() {
  test('Egyptian phone aliases share a canonical identifier', () {
    for (final phone in [
      '01000000001',
      '1000000001',
      '+201000000001',
      '00201000000001',
      '010 0000-0001',
    ]) {
      expect(isEgyptMobilePhone(phone), isTrue);
      expect(normalizeEgyptPhone(phone), '+201000000001');
      expect(phoneAuthIdentifier(phone), 'phone_201000000001@delwaqty.app');
    }
  });
  test('only canonical Egyptian mobile numbers are accepted for signup', () {
    for (final phone in ['', '+441234567890', '+20212345678', '123']) {
      expect(isEgyptMobilePhone(phone), isFalse);
    }
  });
  test(
    'lookup failure canonicalizes local and international login aliases',
    () async {
      for (final phone in [
        '01000000001',
        '+201000000001',
        '00201000000001',
        '1000000001',
      ]) {
        expect(
          await resolvePhoneAuthIdentifier(
            phone,
            (_) async => throw Exception('offline'),
          ),
          'phone_201000000001@delwaqty.app',
        );
        expect(
          await resolvePhoneAuthIdentifier(phone, (_) async => null),
          'phone_201000000001@delwaqty.app',
        );
      }
    },
  );
  test('successful lookup preserves legacy technical emails', () async {
    expect(
      await resolvePhoneAuthIdentifier(
        '01000000001',
        (_) async => 'phone_01000000001@delwaqty.app',
      ),
      'phone_01000000001@delwaqty.app',
    );
  });
}
