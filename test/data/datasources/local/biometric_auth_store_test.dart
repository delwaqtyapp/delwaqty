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

    test(
      'saveCredentials stores credentials and marks the user as active',
      () async {
        await store.saveCredentials(
          userId: 'user-1',
          identifier: '01001112233',
          password: 'secret',
        );

        final credentials = await store.activeCredentials();

        expect(credentials, isNotNull);
        expect(credentials!.identifier, '01001112233');
        expect(credentials.password, 'secret');
      },
    );

    test('credentialsFor reads a specific user', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );

      final credentials = await store.credentialsFor('user-1');

      expect(credentials, isNotNull);
      expect(credentials!.identifier, '01001112233');
      expect(credentials.password, 'secret');
    });

    test('credentialsFor returns null for an unknown user', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );

      expect(await store.credentialsFor('user-2'), isNull);
    });

    test('saving a new user switches the active credentials', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );
      await store.saveCredentials(
        userId: 'user-2',
        identifier: '01099998888',
        password: 'other',
      );

      final credentials = await store.activeCredentials();

      expect(credentials!.identifier, '01099998888');
      expect(credentials.password, 'other');
    });

    test('clearActive removes the active user and its credentials', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
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

    test(
      'clearForUser removes the user credentials and clears the active key',
      () async {
        await store.saveCredentials(
          userId: 'user-1',
          identifier: '01001112233',
          password: 'secret',
        );

        await store.clearForUser('user-1');

        expect(await store.activeCredentials(), isNull);
        expect(await store.credentialsFor('user-1'), isNull);
        expect(await store.hasAnyCredentials(), isFalse);
      },
    );

    test('clearForUser only removes the targeted user', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );
      await store.saveCredentials(
        userId: 'user-2',
        identifier: '01099998888',
        password: 'other',
      );

      await store.clearForUser('user-1');

      expect(await store.credentialsFor('user-1'), isNull);
      expect(await store.credentialsFor('user-2'), isNotNull);
    });

    test(
      'invalidation prevents further biometric auto-login attempts',
      () async {
        await store.saveCredentials(
          userId: 'user-1',
          identifier: '01001112233',
          password: 'secret',
        );

        await store.clearForUser('user-1');

        expect(await store.hasAnyCredentials(), isFalse);
        expect(await store.activeCredentials(), isNull);
      },
    );

    test('credentials can be re-enrolled after invalidation', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'secret',
      );

      await store.clearForUser('user-1');
      await store.saveCredentials(
        userId: 'user-1',
        identifier: '01001112233',
        password: 'new-secret',
      );

      final credentials = await store.activeCredentials();
      expect(credentials, isNotNull);
      expect(credentials!.password, 'new-secret');
    });

    test('legacy email-keyed credential is discarded on read (441: email is not a login identifier)', () async {
      const storage = FlutterSecureStorage();
      // Entry written before the fix: an actual email under the legacy key.
      await storage.write(
        key: 'auth_biometric_user-1',
        value: '{"email":"phone_201001112233@delwaqty.app","password":"secret","userId":"user-1"}',
      );
      await storage.write(key: 'auth_biometric_active_user', value: 'user-1');
      await storage.write(key: 'auth_biometric_index', value: '["user-1"]');

      expect(await store.credentialsFor('user-1'), isNull);
      // Explicitly removed, not just skipped: re-enrollment can proceed.
      expect(await store.hasAnyCredentials(), isFalse);
      expect(await store.activeCredentials(), isNull);
    });

    test('a real email identifier is a valid credential again (467)', () async {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'auth_biometric_user-1',
        value: '{"identifier":"person@example.com","password":"secret","userId":"user-1"}',
      );
      final credentials = await store.credentialsFor('user-1');
      expect(credentials, isNotNull);
      expect(credentials!.identifier, 'person@example.com');
    });

    test('legacy entry with a non-email identifier under the email key still reads', () async {
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'auth_biometric_user-1',
        value: '{"email":"01001112233","password":"secret","userId":"user-1"}',
      );

      final credentials = await store.credentialsFor('user-1');

      expect(credentials, isNotNull);
      expect(credentials!.identifier, '01001112233');
    });

    test('biometricLoginIdentifier prefers phone, falls back to username, never email', () {
      expect(
        biometricLoginIdentifier(phone: '+201001112233', username: 'someone'),
        '+201001112233',
      );
      expect(biometricLoginIdentifier(username: 'someone'), 'someone');
      expect(
        biometricLoginIdentifier(phone: '', username: 'someone'),
        'someone',
      );
      expect(biometricLoginIdentifier(phone: '+201001112233'), '+201001112233');
      expect(biometricLoginIdentifier(), isNull);
      expect(biometricLoginIdentifier(phone: '', username: ''), isNull);
    });

    test('credentialsForIdentifier matches case-insensitively', () async {
      await store.saveCredentials(
        userId: 'user-1',
        identifier: 'SuiteUser',
        password: 'secret',
      );

      final credentials = await store.credentialsForIdentifier('suiteuser');

      expect(credentials, isNotNull);
      expect(credentials!.userId, 'user-1');
    });
  });
}
