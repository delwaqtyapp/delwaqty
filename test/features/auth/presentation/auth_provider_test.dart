import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/enums/verification_status.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSharedPreferencesService extends Mock
    implements SharedPreferencesService {}

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockUserRepository mockUserRepo;
  late MockAppLogger mockLogger;
  late MockSharedPreferencesService mockPrefs;
  late BiometricAuthStore biometricStore;

  final testUser = User(
    id: 'user-123',
    email: 'test@example.com',
    fullName: 'John Doe',
    createdAt: DateTime(2024, 1, 15),
  );

  ProviderContainer buildTestContainer() => ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          loggerProvider.overrideWithValue(mockLogger),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          biometricAuthStoreProvider.overrideWithValue(biometricStore),
        ],
      );

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockUserRepo = MockUserRepository();
    mockLogger = MockAppLogger();
    mockPrefs = MockSharedPreferencesService();
    biometricStore = BiometricAuthStore(const FlutterSecureStorage());
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    when(() => mockPrefs.remove(key: any(named: 'key')))
        .thenAnswer((_) async => true);
  });

  setUpAll(() {
    registerFallbackValue(const AuthResult(userId: '', email: ''));
  });

  group('AuthStateNotifier', () {
    test('has initial state', () {
      final container = buildTestContainer();

      final state = container.read(authStateProvider);
      expect(state, isA<AuthInitial>());
    });

    group('checkAuthStatus', () {
      test('sets unauthenticated when no session', () async {
        when(() => mockAuthRepo.getCurrentSession())
            .thenAnswer((_) async => null);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).checkAuthStatus();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthUnauthenticated>());
      });

      test('sets authenticated when session exists', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com');
        when(() => mockAuthRepo.getCurrentSession())
            .thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).checkAuthStatus();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
      });

      test('sets pendingVerification when user requires verification', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com');
        final pendingUser = testUser.copyWith(
          userType: UserType.provider,
          verificationStatus: VerificationStatus.pending,
        );
        when(() => mockAuthRepo.getCurrentSession())
            .thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => pendingUser);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).checkAuthStatus();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthPendingVerification>());
      });

      test('sets unauthenticated on error', () async {
        when(() => mockAuthRepo.getCurrentSession())
            .thenThrow(Exception('Failed'));

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).checkAuthStatus();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthUnauthenticated>());
      });
    });

    group('signIn', () {
      test('sets authenticated on success', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com');
        when(() => mockAuthRepo.signInWithEmail(
              email: 'test@example.com',
              password: 'password123',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signIn(
              email: 'test@example.com',
              password: 'password123',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
      });

      test('sets error on failure', () async {
        when(() => mockAuthRepo.signInWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
            )).thenThrow(Exception('Invalid credentials'));

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signIn(
              email: 'test@example.com',
              password: 'wrong',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthError>());
      });
    });

    group('signUp', () {
      test('sets authenticated on success with valid session', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com', accessToken: 'valid-token');
        when(() => mockAuthRepo.signUpWithEmail(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signUp(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
      });

      test('sets pendingVerification when user requires verification', () async {
        const session = AuthResult(
          userId: 'user-123',
          email: 'test@example.com',
          accessToken: 'valid-token',
        );
        final pendingUser = testUser.copyWith(
          userType: UserType.delivery,
          verificationStatus: VerificationStatus.pending,
        );
        when(() => mockAuthRepo.signUpWithEmail(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => pendingUser);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signUp(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthPendingVerification>());
      });

      test('sets error on failure', () async {
        when(() => mockAuthRepo.signUpWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
              fullName: any(named: 'fullName'),
            )).thenThrow(Exception('Sign up failed'));

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signUp(
              email: 'test@example.com',
              password: 'password123',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthError>());
      });
    });

    group('signOut', () {
      test('sets unauthenticated on success', () async {
        when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signOut();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthUnauthenticated>());
      });

      test('sets emailConfirmationRequired when no session returned', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com');
        when(() => mockAuthRepo.signUpWithEmail(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            )).thenAnswer((_) async => session);

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signUp(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthEmailConfirmationRequired>());
      });

      test('sets error on failure', () async {
        when(() => mockAuthRepo.signOut())
            .thenThrow(Exception('Sign out failed'));

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signOut();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthError>());
      });
    });

    group('resetPassword', () {
      test('calls resetPassword on repository', () async {
        when(() => mockAuthRepo.resetPassword(email: 'test@example.com'))
            .thenAnswer((_) async {});

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).resetPassword(
              email: 'test@example.com',
            );

        verify(() => mockAuthRepo.resetPassword(email: 'test@example.com'))
            .called(1);
      });
    });

    group('biometric credentials', () {
      Future<void> seedStoredCredentials() async {
        await biometricStore.saveCredentials(
          userId: 'user-123',
          email: 'test@example.com',
          password: 'stale-secret',
        );
      }

      test(
          'failed biometric sign-in followed by invalidation clears the '
          'stale stored credential', () async {
        await seedStoredCredentials();
        when(() => mockAuthRepo.signInWithEmail(
              email: 'test@example.com',
              password: 'stale-secret',
            )).thenThrow(Exception('Invalid login credentials'));

        final container = buildTestContainer();
        final notifier = container.read(authStateProvider.notifier);

        await notifier.signIn(email: 'test@example.com', password: 'stale-secret');
        expect(container.read(authStateProvider), isA<AuthError>());

        await notifier.invalidateBiometricCredentials(userId: 'user-123');

        expect(await biometricStore.hasAnyCredentials(), isFalse);
        expect(await biometricStore.activeCredentials(), isNull);
      });

      test(
          'invalidateBiometricCredentials while authenticated disables the '
          'server biometric flag', () async {
        const session = AuthResult(
          userId: 'user-123',
          email: 'test@example.com',
        );
        when(() => mockAuthRepo.signInWithEmail(
              email: 'test@example.com',
              password: 'password123',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);
        when(() => mockAuthRepo.updateBiometricEnabled(
              userId: any(named: 'userId'),
              enabled: any(named: 'enabled'),
            )).thenAnswer((_) async {});

        final container = buildTestContainer();
        final notifier = container.read(authStateProvider.notifier);

        await notifier.signIn(email: 'test@example.com', password: 'password123');
        await seedStoredCredentials();
        await notifier.invalidateBiometricCredentials(userId: 'user-123');

        verify(() => mockAuthRepo.updateBiometricEnabled(
              userId: 'user-123',
              enabled: false,
            )).called(1);
        expect(await biometricStore.hasAnyCredentials(), isFalse);
      });

      test('signOut preserves biometric credentials', () async {
        await seedStoredCredentials();
        when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

        final container = buildTestContainer();

        await container.read(authStateProvider.notifier).signOut();

        expect(await biometricStore.activeCredentials(), isNotNull);
        expect(await biometricStore.hasAnyCredentials(), isTrue);
      });

      test('deleteAccount clears biometric credentials for the deleted user',
          () async {
        const session = AuthResult(
          userId: 'user-123',
          email: 'test@example.com',
        );
        when(() => mockAuthRepo.signInWithEmail(
              email: 'test@example.com',
              password: 'password123',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);
        when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});

        final container = buildTestContainer();
        final notifier = container.read(authStateProvider.notifier);

        await notifier.signIn(email: 'test@example.com', password: 'password123');
        await seedStoredCredentials();
        await notifier.deleteAccount();

        expect(container.read(authStateProvider), isA<AuthUnauthenticated>());
        expect(await biometricStore.hasAnyCredentials(), isFalse);
        expect(await biometricStore.activeCredentials(), isNull);
      });
    });
  });
}
