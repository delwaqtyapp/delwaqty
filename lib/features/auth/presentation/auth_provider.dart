import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/core/errors/error_handler.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthState> {
  StreamSubscription? _authSubscription;
  bool _isSignUpInProgress = false;
  bool _isSignInInProgress = false;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });
    return const AuthState.initial();
  }

  SignInUseCase get _signInUseCase => ref.read(signInUseCaseProvider);
  SignUpUseCase get _signUpUseCase => ref.read(signUpUseCaseProvider);
  SignInWithPhoneUseCase get _signInWithPhoneUseCase =>
      ref.read(signInWithPhoneUseCaseProvider);
  VerifyOTPUseCase get _verifyOTPUseCase => ref.read(verifyOTPUseCaseProvider);
  SignInWithGoogleUseCase get _signInWithGoogleUseCase =>
      ref.read(signInWithGoogleUseCaseProvider);
  SignInWithAppleUseCase get _signInWithAppleUseCase =>
      ref.read(signInWithAppleUseCaseProvider);
  SignInAnonymouslyUseCase get _signInAnonymouslyUseCase =>
      ref.read(signInAnonymouslyUseCaseProvider);
  SignOutUseCase get _signOutUseCase => ref.read(signOutUseCaseProvider);
  ResetPasswordUseCase get _resetPasswordUseCase =>
      ref.read(resetPasswordUseCaseProvider);
  DeleteAccountUseCase get _deleteAccountUseCase =>
      ref.read(deleteAccountUseCaseProvider);
  AppLogger get _logger => ref.read(loggerProvider);

  void startAuthListener() {
    _authSubscription?.cancel();
    final authRepo = ref.read(authRepositoryProvider);
    _authSubscription = authRepo.onAuthStateChange.listen((event) {
      _logger.i('Auth event: ${event.type}');
      switch (event.type) {
        case AuthEventType.signedIn:
          if (!_isSignUpInProgress && !_isSignInInProgress) {
            checkAuthStatus();
          }
        case AuthEventType.signedOut:
          _isSignUpInProgress = false;
          state = const AuthState.unauthenticated();
        case AuthEventType.tokenRefreshed:
          _logger.i('Token refreshed');
        case AuthEventType.passwordRecovery:
          _logger.i('Password recovery');
        case AuthEventType.mfaChallenge:
          _logger.i('MFA challenge');
      }
    });
  }

  void stopAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }

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

  Future<void> signIn({required String email, required String password}) async {
    _isSignInInProgress = true;
    state = const AuthState.loading();
    try {
      await _signInUseCase(email: email, password: password);
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    } finally {
      _isSignInInProgress = false;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _isSignUpInProgress = true;
    state = const AuthState.loading();
    try {
      final result = await _signUpUseCase(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (result.accessToken == null) {
        state = AuthState.emailConfirmationRequired(email: email);
        _isSignUpInProgress = false;
        return;
      }
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Sign up failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    } finally {
      _isSignUpInProgress = false;
    }
  }

  Future<void> signInWithPhone({required String phone}) async {
    state = const AuthState.loading();
    try {
      await _signInWithPhoneUseCase(phone: phone);
      state = AuthState.phoneVerificationRequired(phone: phone);
    } catch (e) {
      _logger.e('Phone sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> verifyOTP({required String phone, required String otp}) async {
    state = const AuthState.loading();
    try {
      await _verifyOTPUseCase(phone: phone, otp: otp);
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('OTP verification failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();
    try {
      await _signInWithGoogleUseCase();
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Google sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> signInWithApple() async {
    state = const AuthState.loading();
    try {
      await _signInWithAppleUseCase();
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Apple sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> signInAnonymously() async {
    state = const AuthState.loading();
    try {
      await _signInAnonymouslyUseCase();
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = AuthState.authenticated(user: user);
    } catch (e) {
      _logger.e('Anonymous sign in failed', e);
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

  Future<void> deleteAccount() async {
    state = const AuthState.loading();
    try {
      await _deleteAccountUseCase();
      state = const AuthState.unauthenticated();
    } catch (e) {
      _logger.e('Account deletion failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  void enterGuestMode() {
    state = const AuthState.guest();
  }
}
