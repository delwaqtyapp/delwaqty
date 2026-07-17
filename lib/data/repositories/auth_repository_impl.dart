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
  Future<void> signInWithPhone({required String phone}) async {
    try {
      await _dataSource.signInWithPhone(phone: phone);
    } on sb.AuthException catch (e) {
      _logger.e('Phone sign in error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected phone sign in error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult> verifyOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      final response = await _dataSource.verifyOTP(phone: phone, otp: otp);
      return _mapAuthResponse(response);
    } on sb.AuthException catch (e) {
      _logger.e('OTP verification error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected OTP verification error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final initiated = await _dataSource.signInWithGoogle();
      if (!initiated) {
        throw const AuthException(message: 'Google sign in was cancelled');
      }
      final session = _dataSource.currentSession;
      final user = _dataSource.currentSupabaseUser;
      if (session != null && user != null) {
        return _mapSessionToResult(session, user);
      }
      return const AuthResult(userId: '', isNewUser: false);
    } on sb.AuthException catch (e) {
      _logger.e('Google sign in error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected Google sign in error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult> signInWithApple() async {
    try {
      final initiated = await _dataSource.signInWithApple();
      if (!initiated) {
        throw const AuthException(message: 'Apple sign in was cancelled');
      }
      final session = _dataSource.currentSession;
      final user = _dataSource.currentSupabaseUser;
      if (session != null && user != null) {
        return _mapSessionToResult(session, user);
      }
      return const AuthResult(userId: '', isNewUser: false);
    } on sb.AuthException catch (e) {
      _logger.e('Apple sign in error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected Apple sign in error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    try {
      final response = await _dataSource.signInAnonymously();
      return _mapAuthResponse(response);
    } on sb.AuthException catch (e) {
      _logger.e('Anonymous sign in error', e);
      throw AuthException(message: e.message);
    } catch (e) {
      _logger.e('Unexpected anonymous sign in error', e);
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
  Future<void> deleteAccount() async {
    try {
      await _dataSource.deleteAccount();
    } catch (e) {
      _logger.e('Delete account error', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthResult?> getCurrentSession() async {
    final session = _dataSource.currentSession;
    if (session == null) return null;
    final user = _dataSource.currentSupabaseUser;
    if (user == null) return null;
    return _mapSessionToResult(session, user);
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

  @override
  Stream<AuthEvent> get onAuthStateChange {
    return _dataSource.authStateChanges.map((state) {
      final event = state.event;
      final session = state.session;
      final user = session?.user;
      return AuthEvent(
        type: _mapEventType(event),
        userId: user?.id,
        email: user?.email,
        provider: _mapProvider(user),
      );
    });
  }

  AuthResult _mapAuthResponse(sb.AuthResponse response) {
    final user = response.user;
    if (user == null) {
      throw const AuthException(message: 'Authentication failed: no user');
    }
    return AuthResult(
      userId: user.id,
      email: user.email,
      phone: user.phone,
      fullName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      provider: _mapProvider(user),
      accessToken: response.session?.accessToken,
      refreshToken: response.session?.refreshToken,
      isNewUser: response.session != null,
    );
  }

  AuthResult _mapSessionToResult(sb.Session session, sb.User user) {
    return AuthResult(
      userId: user.id,
      email: user.email,
      phone: user.phone,
      fullName: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      provider: _mapProvider(user),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  AuthEventType _mapEventType(sb.AuthChangeEvent event) {
    return switch (event) {
      sb.AuthChangeEvent.signedIn => AuthEventType.signedIn,
      sb.AuthChangeEvent.signedOut => AuthEventType.signedOut,
      sb.AuthChangeEvent.tokenRefreshed => AuthEventType.tokenRefreshed,
      sb.AuthChangeEvent.passwordRecovery => AuthEventType.passwordRecovery,
      _ => AuthEventType.signedIn,
    };
  }

  AuthProviderType _mapProvider(sb.User? user) {
    if (user == null) return AuthProviderType.email;
    final appMetadata = user.appMetadata;
    final provider = appMetadata['provider'] as String?;
    return switch (provider) {
      'google' => AuthProviderType.google,
      'apple' => AuthProviderType.apple,
      'phone' => AuthProviderType.phone,
      'email' => AuthProviderType.email,
      _ =>
        user.email != null
            ? AuthProviderType.email
            : AuthProviderType.anonymous,
    };
  }
}
