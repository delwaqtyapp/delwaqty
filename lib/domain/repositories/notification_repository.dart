import 'package:delwaqty/domain/entities/app_notification.dart';

/// Outcome of a bulk notification operation (mark-all-read / clear-all).
class BulkNotificationResult {
  const BulkNotificationResult({
    required this.completed,
    required this.processed,
    this.limitReached = false,
    this.error,
  });

  /// true when every visible row was processed.
  final bool completed;

  /// Rows handed to the server for marking/deletion before the operation
  /// ended (approximate progress when [completed] is false).
  final int processed;

  /// true when the safety cap stopped the loop before completion.
  final bool limitReached;

  /// The failure that stopped the operation, when a chunk failed midway.
  final Object? error;
}

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String id);

  Future<BulkNotificationResult> markAllAsRead();

  Future<void> deleteNotification(String id);

  Future<BulkNotificationResult> clearAll();

  Future<bool> existsByIdempotencyKey(String key);

  Future<void> deactivateDeviceTokens(String deviceId);
}
