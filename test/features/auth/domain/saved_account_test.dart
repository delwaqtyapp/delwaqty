import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/auth/domain/saved_account.dart';

void main() {
  group('SavedAccount', () {
    test('uses defaults when no arguments are provided', () {
      const account = SavedAccount();

      expect(account.email, '');
      expect(account.displayName, '');
    });

    test('key is a normalized lower-case email', () {
      const account = SavedAccount(
        email: '  User@Example.COM  ',
        displayName: 'User',
      );

      expect(account.key, 'user@example.com');
    });

    test('round-trips through json', () {
      const account = SavedAccount(
        email: 'user@example.com',
        displayName: 'User',
      );

      final decoded = SavedAccount.fromJson(account.toJson());

      expect(decoded, account);
    });

    test('copyWith changes only the given fields', () {
      const account = SavedAccount(email: 'a@b.com');

      final updated = account.copyWith(displayName: 'A');

      expect(updated.email, 'a@b.com');
      expect(updated.displayName, 'A');
    });
  });
}
