import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/data/datasources/remote/supabase_notification_data_source.dart';

final supabaseNotificationRepositoryImplProvider =
    Provider<SupabaseNotificationRepositoryImpl>((ref) {
      return SupabaseNotificationRepositoryImpl(
        ref.watch(supabaseNotificationDataSourceProvider),
      );
    });

class SupabaseNotificationRepositoryImpl implements NotificationRepository {
  SupabaseNotificationRepositoryImpl(this._dataSource);
  final SupabaseNotificationDataSource _dataSource;

  @override
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _dataSource.getNotifications(
        unreadOnly: unreadOnly,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      return await _dataSource.getUnreadCount();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _dataSource.markAsRead(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _dataSource.markAllAsRead();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    try {
      await _dataSource.deleteNotification(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await _dataSource.clearAll();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> existsByIdempotencyKey(String key) async {
    try {
      return await _dataSource.existsByIdempotencyKey(key);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deactivateDeviceTokens(String deviceId) async {
    try {
      await _dataSource.deactivateDeviceTokens(deviceId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
