import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    group('required', () {
      test('returns error for null value', () {
        expect(
          AppValidators.required(null),
          'This field is required',
        );
      });

      test('returns error for empty string', () {
        expect(
          AppValidators.required(''),
          'This field is required',
        );
      });

      test('returns error for whitespace only', () {
        expect(
          AppValidators.required('   '),
          'This field is required',
        );
      });

      test('returns null for valid value', () {
        expect(AppValidators.required('hello'), isNull);
      });

      test('uses custom field name', () {
        expect(
          AppValidators.required(null, 'Email'),
          'Email is required',
        );
      });
    });

    group('email', () {
      test('returns error for null', () {
        expect(AppValidators.email(null), 'Email is required');
      });

      test('returns error for empty', () {
        expect(AppValidators.email(''), 'Email is required');
      });

      test('returns error for invalid email', () {
        expect(AppValidators.email('notanemail'), isNotNull);
      });

      test('returns null for valid email', () {
        expect(AppValidators.email('test@example.com'), isNull);
      });

      test('returns null for valid email with subdomain', () {
        expect(AppValidators.email('user@mail.example.com'), isNull);
      });
    });

    group('phone', () {
      test('returns error for null', () {
        expect(AppValidators.phone(null), isNotNull);
      });

      test('returns null for valid phone', () {
        expect(AppValidators.phone('1234567890'), isNull);
      });

      test('returns null for phone with + prefix', () {
        expect(AppValidators.phone('+1234567890'), isNull);
      });

      test('returns error for too short', () {
        expect(AppValidators.phone('123'), isNotNull);
      });
    });

    group('password', () {
      test('returns error for null', () {
        expect(AppValidators.password(null), isNotNull);
      });

      test('returns error for too short', () {
        expect(AppValidators.password('short'), isNotNull);
      });

      test('returns null for valid password', () {
        expect(AppValidators.password('password123'), isNull);
      });
    });

    group('confirmPassword', () {
      test('returns error if passwords do not match', () {
        expect(
          AppValidators.confirmPassword('password1', 'password2'),
          'Passwords do not match',
        );
      });

      test('returns null if passwords match', () {
        expect(
          AppValidators.confirmPassword('password1', 'password1'),
          isNull,
        );
      });
    });

    group('minLength', () {
      test('returns error for too short', () {
        expect(
          AppValidators.minLength('hi', 5),
          isNotNull,
        );
      });

      test('returns null for sufficient length', () {
        expect(
          AppValidators.minLength('hello', 5),
          isNull,
        );
      });
    });

    group('maxLength', () {
      test('returns error for too long', () {
        expect(
          AppValidators.maxLength('hello world', 5),
          isNotNull,
        );
      });

      test('returns null for acceptable length', () {
        expect(
          AppValidators.maxLength('hi', 5),
          isNull,
        );
      });
    });
  });
}
