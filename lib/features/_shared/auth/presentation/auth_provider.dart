import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';
import 'package:delwaqty/domain/enums/user_type.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/domain/usecases/auth/auth_usecases.dart';
import 'package:delwaqty/domain/usecases/user/get_user.dart';
import 'package:delwaqty/core/errors/error_handler.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/services/push_notification/push_notification_service.dart';

final requireProviderDocumentsProvider = FutureProvider<bool>((ref) async {
  try {
    final row = await Supabase.instance.client
        .from('platform_settings')
        .select('require_provider_documents')
        .eq('id', 'default')
        .maybeSingle();
    return (row?['require_provider_documents'] as bool?) ?? false;
  } catch (_) {
    return false;
  }
});

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthState> {
  StreamSubscription? _authSubscription;
  bool _isSignUpInProgress = false;
  bool _isSignInInProgress = false;
  bool _cachedRequireProviderDocuments = false;

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
  SignOutUseCase get _signOutUseCase => ref.read(signOutUseCaseProvider);
  ResetPasswordUseCase get _resetPasswordUseCase =>
      ref.read(resetPasswordUseCaseProvider);
  DeleteAccountUseCase get _deleteAccountUseCase =>
      ref.read(deleteAccountUseCaseProvider);
  AppLogger get _logger => ref.read(loggerProvider);

  Future<void> _refreshRequireProviderDocuments() async {
    try {
      _cachedRequireProviderDocuments = await ref
          .read(requireProviderDocumentsProvider.future)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      _cachedRequireProviderDocuments = false;
    }
  }

  void startAuthListener() {
    _authSubscription?.cancel();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      _authSubscription = authRepo.onAuthStateChange.listen((event) {
        _logger.i('Auth event: ${event.type}');
        switch (event.type) {
          case AuthEventType.signedIn:
            ref.read(pushNotificationServiceProvider).initialize();
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
    } catch (e) {
      _logger.e('Auth listener start failed', e);
    }
  }

  void stopAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> checkAuthStatus() async {
    state = const AuthState.loading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      var session = await authRepo.getCurrentSession();
      // Persisted session exists but its access token expired (e.g. cold
      // start after 1h): refresh it before deciding the auth state so the
      // customer stays logged in permanently instead of being signed out.
      if (session == null) {
        try {
          await authRepo.refreshSession();
          session = await authRepo.getCurrentSession();
        } catch (_) {}
      }
      if (session != null) {
        await _refreshRequireProviderDocuments();
        final user = await ref
            .read(getCurrentUserUseCaseProvider)
            .call()
            .timeout(const Duration(seconds: 12));
        state = _resolveAuthenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      _logger.e('Auth check failed', e);
      state = const AuthState.unauthenticated();
    }
  }

  /// Signs in with an email, phone number, OR a username. Usernames and phone
  /// numbers are resolved to their auth email through security-definer RPCs
  /// before Supabase auth.
  Future<void> signIn({required String email, required String password}) async {
    _isSignInInProgress = true;
    state = const AuthState.loading();
    try {
      var identifier = email.trim();
      if (!identifier.contains('@')) {
        identifier = await _resolveUsernameToEmail(identifier);
      }
      await _signInUseCase(email: identifier, password: password);
      await _refreshRequireProviderDocuments();
      // Bound the profile fetch so a slow/hanging network after sign-in (e.g.
      // right after a logout) can never leave the app stuck on "loading".
      final user = await ref
          .read(getCurrentUserUseCaseProvider)
          .call()
          .timeout(const Duration(seconds: 12));
      state = _resolveAuthenticated(user);
    } catch (e) {
      _logger.e('Sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    } finally {
      _isSignInInProgress = false;
    }
  }

  /// Launches the Google OAuth flow in the system browser. The session
  /// arrives through the `io.delwaqty://login-callback` deep link; the auth
  /// listener then moves the state to authenticated.
  Future<void> signInWithGoogle() async {
    await _signInWithOAuth(() => ref.read(signInWithGoogleUseCaseProvider)());
  }

  /// Launches the Facebook OAuth flow; same deep-link return as Google.
  Future<void> signInWithFacebook() async {
    await _signInWithOAuth(() => ref.read(signInWithFacebookUseCaseProvider)());
  }

  Future<void> _signInWithOAuth(Future<void> Function() launch) async {
    try {
      await launch();
    } catch (e) {
      _logger.e('OAuth sign in failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  /// Looks up the auth email for a phone number or username through
  /// security-definer RPCs (`lookup_email_by_phone` / `lookup_email_by_username`).
  Future<String> _resolveUsernameToEmail(String identifier) async {
    final trimmed = identifier.trim();
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabaseAnonKey,
    );
    final phonePattern = RegExp(r'^[+0-9][0-9\s\-]{7,}$');
    if (phonePattern.hasMatch(trimmed)) {
      try {
        final resolvedPhone = await client.rpc(
          'lookup_email_by_phone',
          params: {'p_phone': trimmed},
        ) as String?;
        if (resolvedPhone != null && resolvedPhone.isNotEmpty) {
          return resolvedPhone;
        }
      } catch (_) {}
      final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      return 'phone_$digits@delwaqty.app';
    }
    final resolved = await client.rpc(
      'lookup_email_by_username',
      params: {'p_username': trimmed},
    ) as String?;
    if (resolved == null || resolved.isEmpty) {
      throw const AuthException(message: 'Invalid username or password.');
    }
    return resolved;
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? phoneVerificationChallenge,
    UserType userType = UserType.customer,
    String language = 'en',
    Uint8List? idCardBytes,
    String? idCardFileName,
    Uint8List? profilePhotoBytes,
    String? profilePhotoFileName,
    Uint8List? tradeLicenseBytes,
    String? tradeLicenseFileName,
    Uint8List? drivingLicenseBytes,
    String? drivingLicenseFileName,
  }) async {
    _isSignUpInProgress = true;
    state = const AuthState.loading();
    try {
      final result = await _signUpUseCase(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        phoneVerificationChallenge: phoneVerificationChallenge,
        userType: userType,
        language: language,
        idCardBytes: idCardBytes,
        idCardFileName: idCardFileName,
        profilePhotoBytes: profilePhotoBytes,
        profilePhotoFileName: profilePhotoFileName,
        tradeLicenseBytes: tradeLicenseBytes,
        tradeLicenseFileName: tradeLicenseFileName,
        drivingLicenseBytes: drivingLicenseBytes,
        drivingLicenseFileName: drivingLicenseFileName,
      );
      if (result.accessToken == null) {
        state = AuthState.emailConfirmationRequired(email: email);
        _isSignUpInProgress = false;
        return;
      }
      await _refreshRequireProviderDocuments();
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = _resolveAuthenticated(user);
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
      await _refreshRequireProviderDocuments();
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = _resolveAuthenticated(user);
    } catch (e) {
      _logger.e('OTP verification failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  /// Resends the signup confirmation email through GoTrue (works for any
  /// account still in the unconfirmed state, e.g. after a missed activation
  /// link). Re-throws so callers can surface the outcome in the UI.
  Future<void> resendEmailConfirmation({required String email}) async {
    try {
      await ref.read(resendEmailConfirmationUseCaseProvider).call(email: email);
    } catch (e, stack) {
      _logger.e('Resend confirmation failed', e, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AuthState.loading();
    try {
      try {
        final pushService = ref.read(pushNotificationServiceProvider);
        await pushService.deactivateTokensOnLogout();
      } catch (_) {}
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
    final current = state;
    final userId = current.whenOrNull(authenticated: (user) => user.id);
    state = const AuthState.loading();
    try {
      await _deleteAccountUseCase();
      if (userId != null && userId.isNotEmpty) {
        try {
          await ref.read(biometricAuthStoreProvider).clearForUser(userId);
        } catch (_) {}
      }
      state = const AuthState.unauthenticated();
    } catch (e) {
      _logger.e('Account deletion failed', e);
      final failure = handleException(e);
      state = AuthState.error(message: failure.message);
    }
  }

  Future<void> updateBiometricEnabled({required bool enabled}) async {
    final current = state;
    if (current is! AuthAuthenticated) return;
    try {
      await ref
          .read(updateBiometricEnabledUseCaseProvider)
          .call(userId: current.user.id, enabled: enabled);
      final user = await ref.read(getCurrentUserUseCaseProvider).call();
      state = _resolveAuthenticated(user);
    } catch (e) {
      _logger.e('Failed to update biometric flag', e);
    }
  }

  Future<void> invalidateBiometricCredentials({required String userId}) async {
    try {
      await ref.read(biometricAuthStoreProvider).clearForUser(userId);
    } catch (_) {}
    final current = state;
    if (current is AuthAuthenticated && current.user.id == userId) {
      try {
        await updateBiometricEnabled(enabled: false);
      } catch (_) {}
    }
  }

  void enterGuestMode() {
    state = const AuthState.guest();
  }

  AuthState _resolveAuthenticated(User user) {
    final requireDocs =
        ref.read(requireProviderDocumentsProvider).asData?.value ??
        _cachedRequireProviderDocuments;
    final isMerchantOrProvider =
        user.userType == UserType.merchant ||
        user.userType == UserType.provider;
    if (isMerchantOrProvider && !requireDocs) {
      return AuthState.authenticated(user: user);
    }
    if (user.userType.requiresVerification &&
        !user.verificationStatus.isApproved) {
      return const AuthState.pendingVerification();
    }
    return AuthState.authenticated(user: user);
  }
}
