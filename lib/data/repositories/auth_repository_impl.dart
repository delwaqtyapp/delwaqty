import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/domain/repositories/auth_repository.dart';
import 'package:delwaqty/data/datasources/remote/supabase_auth_data_source.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final authRepositoryImplProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    ref.watch(supabaseAuthDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource, this._logger);

  final SupabaseAuthDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return _mapAuthResponse(response);
    } on sb.AuthException catch (e) {
      _logger.e('Auth sign in error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected sign in error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _dataSource.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      return _mapAuthResponse(response);
    } on sb.AuthException catch (e) {
      _logger.e('Auth sign up error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected sign up error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _dataSource.signOut();
    } catch (e) {
      _logger.e('Sign out error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _dataSource.resetPassword(email);
    } catch (e) {
      _logger.e('Reset password error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult?> getCurrentSession() async {
    final session = _dataSource.currentSession;
    if (session == null) return null;
    final user = _dataSource.currentSupabaseUser;
    if (user == null) return null;
    return AuthResult(
      userId: user.id,
      email: user.email ?? '',
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  @override
  Future<void> refreshSession() async {
    try {
      await _dataSource.refreshSession();
    } on sb.AuthException catch (e) {
      _logger.e('Session refresh failed', e);
      throw AuthException(message: e.message);
    }
  }

  AuthResult _mapAuthResponse(sb.AuthResponse response) {
    final user = response.user;
    if (user == null) {
      throw const AuthException(message: 'Authentication failed: no user');
    }
    return AuthResult(
      userId: user.id,
      email: user.email ?? '',
      accessToken: response.session?.accessToken,
      refreshToken: response.session?.refreshToken,
    );
  }
}
