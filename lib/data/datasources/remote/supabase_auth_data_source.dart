import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((ref) {
  return SupabaseAuthDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

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

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? userType = 'customer',
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'user_type': userType,
          'verification_status':
              userType == 'customer' ? 'approved' : 'pending',
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
        redirectTo: 'io.delwaqty://login-callback',
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
        redirectTo: 'io.delwaqty://login-callback',
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
        redirectTo: 'io.delwaqty://login-callback',
      );
      _logger.i('Facebook sign in initiated');
      return response;
    } catch (e, stack) {
      _logger.e('Facebook sign in failed', e, stack);
      rethrow;
    }
  }

  Future<AuthResponse> signInAnonymously() async {
    try {
      final response = await _auth.signInAnonymously();
      _logger.i('Anonymous sign in successful');
      return response;
    } catch (e, stack) {
      _logger.e('Anonymous sign in failed', e, stack);
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
      _logger.i('Account deletion requested');
    } catch (e, stack) {
      _logger.e('Account deletion failed', e, stack);
      rethrow;
    }
  }

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
