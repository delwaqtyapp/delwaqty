import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/core/errors/error_handler.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

  SignInUseCase get _signInUseCase => ref.read(signInUseCaseProvider);
  SignUpUseCase get _signUpUseCase => ref.read(signUpUseCaseProvider);
  SignOutUseCase get _signOutUseCase => ref.read(signOutUseCaseProvider);
  ResetPasswordUseCase get _resetPasswordUseCase =>
      ref.read(resetPasswordUseCaseProvider);
  AppLogger get _logger => ref.read(loggerProvider);

  Future<void> checkAuthStatus() async {
    state = const AuthState.loading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final session = await authRepo.getCurrentSession();
      if (session != null) {
        final user = await ref.read(getCurrentUserUseCaseProvider).call();
        state = AuthState.authenticated(user: user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      _logger.e('Auth check failed', e);
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      await _signInUseCase(email: email, password: password);
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AuthState.loading();
    try {
      await _signUpUseCase(email: email, password: password, fullName: fullName);
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Sign up failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> signOut() async {
    state = const AuthState.loading();
    try {
      await _signOutUseCase();
      state = const AuthState.unauthenticated();
    } catch (e) {
      _logger.e('Sign out failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _resetPasswordUseCase(email: email);
    } catch (e) {
      _logger.e('Password reset failed', e);
      rethrow;
    }
  }
}
