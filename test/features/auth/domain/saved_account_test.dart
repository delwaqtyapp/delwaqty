import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/auth/domain/saved_account.dart';

void main() {
  group('SavedAccount', () {
    test('uses defaults when no arguments are provided', () {
      const account = SavedAccount();

      expect(account.email, '');
      expect(account.displayName, '');
      expect(account.hasBiometric, isFalse);
    });

    test('key is a normalized lower-case email', () {
      const account = SavedAccount(
        email: '  User@Example.COM  ',
        displayName: 'User',
        hasBiometric: true,
      );

      expect(account.key, 'user@example.com');
      expect(account.hasBiometric, isTrue);
    });

    test('round-trips through json', () {
      const account = SavedAccount(
        email: 'user@example.com',
        displayName: 'User',
        hasBiometric: true,
      );

      final decoded = SavedAccount.fromJson(account.toJson());

      expect(decoded, account);
    });

    test('copyWith changes only the given fields', () {
      const account = SavedAccount(email: 'a@b.com');

      final updated = account.copyWith(
        displayName: 'A',
        hasBiometric: true,
      );

      expect(updated.email, 'a@b.com');
      expect(updated.displayName, 'A');
      expect(updated.hasBiometric, isTrue);
    });
  });
}
