import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/utils/validators.dart';

void main() {
  group('AppValidators.isValidUsername (mirrors migration 439)', () {
    test('accepts letters, digits, underscore, 3-30 chars', () {
      expect(AppValidators.isValidUsername('ahmed_99'), isTrue);
      expect(AppValidators.isValidUsername('SuperAdmin'), isTrue);
      expect(AppValidators.isValidUsername('abc'), isTrue);
      expect(AppValidators.isValidUsername('a' * 30), isTrue);
    });

    test('rejects dots, dashes, spaces, punctuation', () {
      expect(AppValidators.isValidUsername('john.doe'), isFalse);
      expect(AppValidators.isValidUsername('ok-name-9'), isFalse);
      expect(AppValidators.isValidUsername('no spaces'), isFalse);
    });

    test('rejects too short and too long', () {
      expect(AppValidators.isValidUsername('ab'), isFalse);
      expect(AppValidators.isValidUsername('a' * 31), isFalse);
    });

    test('rejects all-digit names (reserved for the phone login path)', () {
      expect(AppValidators.isValidUsername('012345678'), isFalse);
      expect(AppValidators.isValidUsername('123'), isFalse);
      expect(AppValidators.isValidUsername('123456789012345678901'), isFalse);
    });
  });

  group('AppValidators.loginIdentifier', () {
    test('accepts phone shapes', () {
      expect(AppValidators.loginIdentifier('01012345678'), isNull);
      expect(AppValidators.loginIdentifier('+201012345678'), isNull);
    });

    test('accepts email-shaped identifiers (legacy accounts)', () {
      expect(AppValidators.loginIdentifier('user@example.com'), isNull);
    });

    test('accepts a valid username, rejects invalid ones', () {
      expect(AppValidators.loginIdentifier('ahmed_99'), isNull);
      expect(AppValidators.loginIdentifier('john.doe'), isNotNull);
      expect(AppValidators.loginIdentifier('a' * 31), isNotNull);
    });
  });
}
