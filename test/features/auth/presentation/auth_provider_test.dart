import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/domain/entities/user.dart';
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

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockUserRepository mockUserRepo;
  late MockAppLogger mockLogger;

  final testUser = User(
    id: 'user-123',
    email: 'test@example.com',
    fullName: 'John Doe',
    createdAt: DateTime(2024, 1, 15),
  );

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockUserRepo = MockUserRepository();
    mockLogger = MockAppLogger();
  });

  setUpAll(() {
    registerFallbackValue(const AuthResult(userId: '', email: ''));
  });

  group('AuthStateNotifier', () {
    test('has initial state', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          loggerProvider.overrideWithValue(mockLogger),
        ],
      );

      final state = container.read(authStateProvider);
      expect(state, isA<AuthInitial>());
    });

    group('checkAuthStatus', () {
      test('sets unauthenticated when no session', () async {
        when(() => mockAuthRepo.getCurrentSession())
            .thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

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

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).checkAuthStatus();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
      });

      test('sets unauthenticated on error', () async {
        when(() => mockAuthRepo.getCurrentSession())
            .thenThrow(Exception('Failed'));

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

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

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

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

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).signIn(
              email: 'test@example.com',
              password: 'wrong',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthError>());
      });
    });

    group('signUp', () {
      test('sets authenticated on success', () async {
        const session = AuthResult(userId: 'user-123', email: 'test@example.com');
        when(() => mockAuthRepo.signUpWithEmail(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            )).thenAnswer((_) async => session);
        when(() => mockUserRepo.getCurrentUser())
            .thenAnswer((_) async => testUser);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).signUp(
              email: 'test@example.com',
              password: 'password123',
              fullName: 'John Doe',
            );

        final state = container.read(authStateProvider);
        expect(state, isA<AuthAuthenticated>());
      });

      test('sets error on failure', () async {
        when(() => mockAuthRepo.signUpWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
              fullName: any(named: 'fullName'),
            )).thenThrow(Exception('Sign up failed'));

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

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

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).signOut();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthUnauthenticated>());
      });

      test('sets error on failure', () async {
        when(() => mockAuthRepo.signOut())
            .thenThrow(Exception('Sign out failed'));

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).signOut();

        final state = container.read(authStateProvider);
        expect(state, isA<AuthError>());
      });
    });

    group('resetPassword', () {
      test('calls resetPassword on repository', () async {
        when(() => mockAuthRepo.resetPassword(email: 'test@example.com'))
            .thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
            userRepositoryProvider.overrideWithValue(mockUserRepo),
            loggerProvider.overrideWithValue(mockLogger),
          ],
        );

        await container.read(authStateProvider.notifier).resetPassword(
              email: 'test@example.com',
            );

        verify(() => mockAuthRepo.resetPassword(email: 'test@example.com'))
            .called(1);
      });
    });
  });
}
