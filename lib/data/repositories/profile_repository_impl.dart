import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/domain/repositories/profile_repository.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/data/datasources/remote/supabase_profile_data_source.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final profileRepositoryImplProvider = Provider<ProfileRepositoryImpl>((ref) {
  return ProfileRepositoryImpl(
    ref.watch(supabaseProfileDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dataSource, this._logger);

  final SupabaseProfileDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<User> getProfile(String userId) async {
    try {
      final model = await _dataSource.getProfile(userId);
      return model.toEntity();
    } catch (e) {
      _logger.e('Failed to get profile: $userId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<User> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final model = await _dataSource.updateProfile(userId: userId, data: data);
      return model.toEntity();
    } catch (e) {
      _logger.e('Failed to update profile: $userId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<User> updateDateOfBirth({
    required String userId,
    required DateTime? dateOfBirth,
  }) async {
    try {
      final model = await _dataSource.updateDateOfBirth(
        userId: userId,
        dateOfBirth: dateOfBirth,
      );
      return model.toEntity();
    } catch (e) {
      _logger.e('Failed to update date of birth: $userId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      return _dataSource.uploadAvatar(
        userId: userId,
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );
    } catch (e) {
      _logger.e('Failed to upload avatar: $userId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadDocument({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      return _dataSource.uploadFile(
        userId: userId,
        folder: 'documents',
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );
    } catch (e) {
      _logger.e('Failed to upload document: $userId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<User> watchProfile(String userId) {
    return _dataSource.watchProfile(userId).map((model) => model.toEntity());
  }
}
