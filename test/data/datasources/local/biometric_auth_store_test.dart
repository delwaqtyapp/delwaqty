import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';

void main() {
  late BiometricAuthStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    store = BiometricAuthStore(const FlutterSecureStorage());
  });

  group('BiometricAuthStore', () {
    test('activeCredentials returns null when nothing is saved', () async {
      expect(await store.activeCredentials(), isNull);
    });

    test('saveCredentials stores credentials and marks the user as active',
        () async {
      await store.saveCredentials(
        userId: 'user-1',
        email: 'a@b.com',
        password: 'secret',
      );

      final credentials = await store.activeCredentials();

      expect(credentials, isNotNull);
      expect(credentials!.email, 'a@b.com');
      expect(credentials.password, 'secret');
    });

    test('credentialsFor reads a specific user', () async {
      await store.saveCredentials(
        userId: 'user-1',
        email: 'a@b.com',
        password: 'secret',
      );

      final credentials = await store.credentialsFor('user-1');

      expect(credentials, isNotNull);
      expect(credentials!.email, 'a@b.com');
      expect(credentials.password, 'secret');
    });

    test('credentialsFor returns null for an unknown user', () async {
      await store.saveCredentials(
        userId: 'user-1',
        email: 'a@b.com',
        password: 'secret',
      );

      expect(await store.credentialsFor('user-2'), isNull);
    });

    test('saving a new user switches the active credentials', () async {
      await store.saveCredentials(
        userId: 'user-1',
        email: 'a@b.com',
        password: 'secret',
      );
      await store.saveCredentials(
        userId: 'user-2',
        email: 'c@d.com',
        password: 'other',
      );

      final credentials = await store.activeCredentials();

      expect(credentials!.email, 'c@d.com');
      expect(credentials.password, 'other');
    });

    test('clearActive removes the active user and its credentials', () async {
      await store.saveCredentials(
        userId: 'user-1',
        email: 'a@b.com',
        password: 'secret',
      );

      await store.clearActive();

      expect(await store.activeCredentials(), isNull);
      expect(await store.credentialsFor('user-1'), isNull);
    });

    test('clearActive is a no-op when no user is active', () async {
      await store.clearActive();
      expect(await store.activeCredentials(), isNull);
    });

    test('returns null for a corrupt stored payload', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'auth_biometric_user-1', value: 'not-json');

      expect(await store.credentialsFor('user-1'), isNull);
    });
  });
}
