import 'package:delwaqty/domain/entities/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String id);

  Future<void> markAllAsRead();

  Future<void> deleteNotification(String id);

  Future<void> clearAll();

  Future<bool> existsByIdempotencyKey(String key);

  Future<void> deactivateAllTokens();
}
