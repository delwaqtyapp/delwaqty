import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final supabaseAuthDataSourceProvider = Provider<SupabaseAuthDataSource>((
  ref,
) {
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
      _logger.i('Sign in successful for ${response.user?.email}');
      return response;
    } catch (e, stack) {
      _logger.e('Sign in failed', e, stack);
      rethrow;
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      _logger.i('Sign up successful for ${response.user?.email}');
      return response;
    } catch (e, stack) {
      _logger.e('Sign up failed', e, stack);
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

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}
