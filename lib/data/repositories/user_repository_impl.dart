import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/domain/repositories/user_repository.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/data/datasources/remote/supabase_auth_data_source.dart';
import 'package:delwaqty/data/datasources/remote/supabase_profile_data_source.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final userRepositoryImplProvider = Provider<UserRepositoryImpl>((ref) {
  return UserRepositoryImpl(
    ref.watch(supabaseAuthDataSourceProvider),
    ref.watch(supabaseProfileDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(
    this._authDataSource,
    this._profileDataSource,
    this._logger,
  );

  final SupabaseAuthDataSource _authDataSource;
  final SupabaseProfileDataSource _profileDataSource;
  final AppLogger _logger;

  @override
  Future<User> getCurrentUser() async {
    try {
      final supabaseUser = _authDataSource.currentSupabaseUser;
      if (supabaseUser == null) {
        throw const AuthException(message: 'No authenticated user');
      }
      final model = await _profileDataSource.getProfile(supabaseUser.id);
      return model.toEntity();
    } on AuthException {
      rethrow;
    } catch (e) {
      _logger.e('Failed to get current user', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<User> getUserById(String id) async {
    try {
      final model = await _profileDataSource.getProfile(id);
      return model.toEntity();
    } catch (e) {
      _logger.e('Failed to get user by id: $id', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<User> updateUser({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      final model = await _profileDataSource.updateProfile(
        userId: id,
        data: data,
      );
      return model.toEntity();
    } catch (e) {
      _logger.e('Failed to update user: $id', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteUser(String id) async {
    try {
      await _profileDataSource.deleteProfile(id);
      _logger.i('User profile deleted: $id');
    } catch (e) {
      _logger.e('Failed to delete user: $id', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateLanguage({
    required String userId,
    required String language,
  }) async {
    try {
      await _profileDataSource.updateProfile(
        userId: userId,
        data: {'language': language},
      );
    } catch (e) {
      _logger.e('Failed to update language for: $userId', e);
      throw ServerException(message: e.toString());
    }
  }
}
