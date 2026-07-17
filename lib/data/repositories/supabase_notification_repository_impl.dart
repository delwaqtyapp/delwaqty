import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return _dataSource.getNotifications(
      unreadOnly: unreadOnly,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    return _dataSource.getUnreadCount();
  }

  @override
  Future<void> markAsRead(String id) async {
    await _dataSource.markAsRead(id);
  }

  @override
  Future<void> markAllAsRead() async {
    await _dataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String id) async {
    await _dataSource.deleteNotification(id);
  }

  @override
  Future<void> clearAll() async {
    await _dataSource.clearAll();
  }
}
