import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/datasources/local/saved_accounts_store.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';

void main() {
  late SharedPreferencesService prefs;
  late SavedAccountsStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final instance = await SharedPreferences.getInstance();
    prefs = SharedPreferencesService(instance);
    store = SavedAccountsStore(prefs);
  });

  group('SavedAccountsStore', () {
    test('loadAccounts returns empty list when nothing is saved', () async {
      final accounts = await store.loadAccounts();

      expect(accounts, isEmpty);
    });

    test('loadAccounts returns stored accounts', () async {
      await store.saveAccount(
        email: 'user@example.com',
        displayName: 'User',
      );

      final accounts = await store.loadAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.single.email, 'user@example.com');
      expect(accounts.single.displayName, 'User');
    });

    test('saveAccount updates an existing account without duplicating', () async {
      await store.saveAccount(email: 'a@b.com', displayName: 'A');
      await store.saveAccount(email: 'a@b.com', displayName: 'A renamed');

      final accounts = await store.loadAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.single.displayName, 'A renamed');
    });

    test('saveAccount normalizes the email key', () async {
      await store.saveAccount(email: 'A@B.com', displayName: 'AB');
      await store.saveAccount(email: 'a@b.com', displayName: 'AB');

      final accounts = await store.loadAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.single.email, 'a@b.com');
    });

    test('removeAccount removes the account', () async {
      await store.saveAccount(email: 'a@b.com');
      await store.saveAccount(email: 'c@d.com');

      final accounts = await store.removeAccount('A@B.com');

      expect(accounts, hasLength(1));
      expect(accounts.single.email, 'c@d.com');
    });
  });
}
