import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';

/// OAuth return URL per flavor. The admin app owns its own scheme
/// (`io.delwaqty.admin`, see android/app/src/admin/AndroidManifest.xml) so its
/// OAuth callback can be routed to it when several flavors share a device;
/// every other flavor uses `io.delwaqty`.
String oauthRedirectToForFlavor(AppFlavor flavor) => flavor == AppFlavor.admin
    ? 'io.delwaqty.admin://login-callback'
    : 'io.delwaqty://login-callback';

final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
    oauthRedirectTo: oauthRedirectToForFlavor(ref.watch(appFlavorProvider)),
  );
});

class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client, this._logger, {String? oauthRedirectTo})
    : _oauthRedirectTo = oauthRedirectTo ?? 'io.delwaqty://login-callback';

  final SupabaseClient _client;
  final AppLogger _logger;
  final String _oauthRedirectTo;

  GoTrueClient get _auth => _client.auth;

  User? get currentSupabaseUser => _auth.currentUser;
  Session? get currentSession => _auth.currentSession;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      _logger.i('Email sign in successful for ${response.user?.email}');
      return response;
    } catch (e, stack) {
      _logger.e('Email sign in failed', e, stack);
      rethrow;
    }
  }

  /// Signs in through the auth-login-identifier edge function: the
  /// identifier (phone or username) and password go to the server,
  /// which resolves the account and checks the password with GoTrue.
  /// Scope: no email is disclosed before authentication, and the edge
  /// response carries no standalone user object - only session tokens.
  /// The adopted SDK session then holds the normal authenticated session
  /// data, as with any Supabase sign-in.
  Future<AuthResponse> signInWithIdentifier({
    required String identifier,
    required String password,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'auth-login-identifier',
        body: {'identifier': identifier, 'password': password},
      );
      // Adopt the session only from a well-formed 200 payload; anything
      // else is a normalized, stable failure - never backend text.
      final data = res.data;
      final token = data is Map<String, dynamic> ? data['refresh_token'] : null;
      if (res.status != 200 || token is! String || token.isEmpty) {
        _logger.e(
          'Identifier sign in malformed response, status ${res.status}',
        );
        throw const AuthException('Sign in is temporarily unavailable.');
      }
      try {
        final session = await _auth.setSession(token);
        _logger.i('Identifier sign in successful');
        return session;
      } catch (_) {
        _logger.e('Identifier sign in session adoption failed');
        throw const AuthException('Sign in is temporarily unavailable.');
      }
    } on FunctionException catch (e) {
      _logger.e('Identifier sign in failed with status ${e.status}');
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      if (e.status == 401 ||
          code == 'invalid_credentials' ||
          e.status == 400 ||
          code == 'bad_request') {
        throw const AuthException('Invalid username or password.');
      }
      if (e.status == 429 || code == 'too_many_attempts') {
        throw const AuthException('Too many attempts. Please try again later.');
      }
      throw const AuthException('Sign in is temporarily unavailable.');
    } on AuthException {
      rethrow;
    } catch (e) {
      // Transport and unexpected failures: log only the safe error class,
      // never the raw exception, payload or stack.
      _logger.e('Identifier sign in ${e.runtimeType}');
      throw const AuthException('Sign in is temporarily unavailable.');
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? phoneVerificationChallenge,
    String? userType = 'customer',
    String? language = 'en',
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        // The activation email returns here; the app then shows the login
        // page with an "account active" message.
        emailRedirectTo: '$_oauthRedirectTo/activated',
        data: {
          'full_name': fullName,
          'phone': phone,
          if (phoneVerificationChallenge != null)
            'phone_verification_challenge': phoneVerificationChallenge,
          'user_type': userType,
          'language': language,
          'verification_status': userType == 'customer'
              ? 'approved'
              : 'pending',
        },
      );
      _logger.i('Email sign up successful for ${response.user?.email}');
      return response;
    } catch (e, stack) {
      _logger.e('Email sign up failed', e, stack);
      rethrow;
    }
  }

  Future<void> signInWithPhone({required String phone}) async {
    try {
      await _auth.signInWithOtp(phone: phone);
      _logger.i('OTP sent to $phone');
    } catch (e, stack) {
      _logger.e('Phone OTP send failed', e, stack);
      rethrow;
    }
  }

  Future<AuthResponse> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      _logger.i('OTP verified for $phone');
      return response;
    } catch (e, stack) {
      _logger.e('OTP verification failed', e, stack);
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final response = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectTo,
      );
      _logger.i('Google sign in initiated');
      return response;
    } catch (e, stack) {
      _logger.e('Google sign in failed', e, stack);
      rethrow;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      final response = await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _oauthRedirectTo,
      );
      _logger.i('Apple sign in initiated');
      return response;
    } catch (e, stack) {
      _logger.e('Apple sign in failed', e, stack);
      rethrow;
    }
  }

  Future<bool> signInWithFacebook() async {
    try {
      final response = await _auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _oauthRedirectTo,
      );
      _logger.i('Facebook sign in initiated');
      return response;
    } catch (e, stack) {
      _logger.e('Facebook sign in failed', e, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _logger.i('Sign out successful');
    } catch (e, stack) {
      _logger.e('Sign out failed', e, stack);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
      _logger.i('Password reset email sent to $email');
    } catch (e, stack) {
      _logger.e('Password reset failed', e, stack);
      rethrow;
    }
  }

  Future<void> resendEmailConfirmation({required String email}) async {
    try {
      await _auth.resend(email: email, type: OtpType.signup);
      _logger.i('Confirmation email resent to $email');
    } catch (e, stack) {
      _logger.e('Confirmation email resend failed', e, stack);
      rethrow;
    }
  }

  Future<void> refreshSession() async {
    try {
      await _auth.refreshSession();
      _logger.i('Session refreshed successfully');
    } catch (e, stack) {
      _logger.e('Session refresh failed', e, stack);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      await _client.functions.invoke('delete-user');
      _logger.i('Account deletion completed');
    } catch (e, stack) {
      _logger.e('Account deletion failed', e, stack);
      rethrow;
    }
  }

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
