import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/data/models/user_model.dart';

final supabaseProfileDataSourceProvider = Provider<SupabaseProfileDataSource>((
  ref,
) {
  return SupabaseProfileDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseProfileDataSource {
  SupabaseProfileDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _tableName = 'users';

  Future<UserModel> getProfile(String userId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromSupabase(data);
    } catch (e, stack) {
      _logger.e('Failed to get profile for $userId', e, stack);
      rethrow;
    }
  }

  Future<UserModel> updateProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final updated = await _client
          .from(_tableName)
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId)
          .select()
          .single();
      return UserModel.fromSupabase(updated);
    } catch (e, stack) {
      _logger.e('Failed to update profile for $userId', e, stack);
      rethrow;
    }
  }

  Future<UserModel> updateDateOfBirth({
    required String userId,
    required DateTime? dateOfBirth,
  }) async {
    try {
      final date = dateOfBirth == null
          ? null
          : DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
      await _client.rpc(
        'update_member_dob',
        params: {
          'p_date_of_birth': date?.toIso8601String(),
          'p_member_id': userId,
        },
      );
      return getProfile(userId);
    } catch (e, stack) {
      _logger.e('Failed to update date of birth for $userId', e, stack);
      rethrow;
    }
  }

  Future<UserModel> createProfile(UserModel model) async {
    try {
      final data = await _client
          .from(_tableName)
          .insert(model.toInsertJson())
          .select()
          .single();
      return UserModel.fromSupabase(data);
    } catch (e, stack) {
      _logger.e('Failed to create profile for ${model.id}', e, stack);
      rethrow;
    }
  }

  Future<UserModel> upsertProfile(UserModel model) async {
    try {
      final data = await _client
          .from(_tableName)
          .upsert(model.toInsertJson(), onConflict: 'id')
          .select()
          .single();
      return UserModel.fromSupabase(data);
    } catch (e, stack) {
      _logger.e('Failed to upsert profile for ${model.id}', e, stack);
      rethrow;
    }
  }

  Future<String> uploadFile({
    required String userId,
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final path = '$folder/$userId/$fileName';
      await _client.storage.from('profiles').uploadBinary(path, bytes);
      return _client.storage.from('profiles').getPublicUrl(path);
    } catch (e, stack) {
      _logger.e('Failed to upload file to $folder for $userId', e, stack);
      rethrow;
    }
  }

  Future<void> deleteProfile(String userId) async {
    try {
      await _client.from(_tableName).delete().eq('id', userId);
      _logger.i('Profile deleted for $userId');
    } catch (e, stack) {
      _logger.e('Failed to delete profile for $userId', e, stack);
      rethrow;
    }
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final path = 'avatars/$userId/$fileName';
      await _client.storage.from('profiles').uploadBinary(path, bytes);
      final url = _client.storage.from('profiles').getPublicUrl(path);
      _logger.i('Avatar uploaded for $userId');
      return url;
    } catch (e, stack) {
      _logger.e('Failed to upload avatar for $userId', e, stack);
      rethrow;
    }
  }

  Stream<UserModel> watchProfile(String userId) {
    final controller = StreamController<UserModel>.broadcast();

    Future<void> fetch() async {
      try {
        final model = await getProfile(userId);
        if (!controller.isClosed) {
          controller.add(model);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    fetch();

    final subscription = _client
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && !controller.isClosed) {
            controller.add(UserModel.fromSupabase(data.first));
          }
        });

    controller.onCancel = () {
      subscription.cancel();
      if (!controller.isClosed) {
        controller.close();
      }
    };

    return controller.stream;
  }
}
