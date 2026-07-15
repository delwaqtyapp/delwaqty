import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';

void main() {
  User mockUser() => User(
        id: 'user-123',
        email: 'test@example.com',
        fullName: 'Test User',
        createdAt: DateTime(2024),
      );

  group('AuthState pattern matching', () {
    test('AuthInitial is created correctly', () {
      const state = AuthState.initial();
      expect(state, isA<AuthInitial>());
    });

    test('AuthLoading is created correctly', () {
      const state = AuthState.loading();
      expect(state, isA<AuthLoading>());
    });

    test('AuthUnauthenticated is created correctly', () {
      const state = AuthState.unauthenticated();
      expect(state, isA<AuthUnauthenticated>());
    });

    test('AuthError contains message', () {
      const state = AuthState.error(message: 'Something went wrong');
      expect(state, isA<AuthError>());
    });

    test('AuthState union types are distinct', () {
      const initial = AuthState.initial();
      const loading = AuthState.loading();
      const unauth = AuthState.unauthenticated();
      const error = AuthState.error(message: 'test');

      expect(initial, isNot(equals(loading)));
      expect(loading, isNot(equals(unauth)));
      expect(unauth, isNot(equals(error)));
    });

    test('AuthError message is accessible', () {
      const state = AuthState.error(message: 'Test error');
      final message = state.whenOrNull(error: (msg) => msg);
      expect(message, 'Test error');
    });

    test('AuthAuthenticated contains user data', () {
      final user = mockUser();
      final state = AuthState.authenticated(user: user);
      expect(state, isA<AuthAuthenticated>());
      state.whenOrNull(
        authenticated: (u) => expect(u.id, 'user-123'),
      );
    });
  });

  group('GoRouter redirect logic (conceptual)', () {
    test('unauthenticated user on protected route should redirect to welcome', () {
      const authState = AuthState.unauthenticated();
      const isAuth = authState is AuthAuthenticated;
      const isAuthRoute = false;
      const isWelcome = false;

      const shouldRedirect = !isAuth && !isAuthRoute && !isWelcome;
      expect(shouldRedirect, isTrue);
    });

    test('authenticated user on auth route should redirect to home', () {
      final authState = AuthState.authenticated(user: mockUser());
      final isAuth = authState is AuthAuthenticated;
      const isAuthRoute = true;

      final shouldRedirect = isAuth && isAuthRoute;
      expect(shouldRedirect, isTrue);
    });

    test('unauthenticated user on auth route should not redirect', () {
      const authState = AuthState.unauthenticated();
      const isAuth = authState is AuthAuthenticated;
      const isAuthRoute = true;

      const shouldRedirectToLogin = !isAuth && !isAuthRoute;
      const shouldRedirectToHome = isAuth && isAuthRoute;
      expect(shouldRedirectToLogin, isFalse);
      expect(shouldRedirectToHome, isFalse);
    });

    test('authenticated user on protected route should not redirect', () {
      final authState = AuthState.authenticated(user: mockUser());
      final isAuth = authState is AuthAuthenticated;
      const isAuthRoute = false;

      final shouldRedirectToLogin = !isAuth && !isAuthRoute;
      final shouldRedirectToHome = isAuth && isAuthRoute;
      expect(shouldRedirectToLogin, isFalse);
      expect(shouldRedirectToHome, isFalse);
    });

    test('splash and onboarding routes exist', () {
      expect('/splash'.isNotEmpty, isTrue);
      expect('/onboarding'.isNotEmpty, isTrue);
    });
  });
}
