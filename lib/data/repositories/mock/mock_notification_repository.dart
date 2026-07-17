import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: 'Order Confirmed',
      body: 'Your order from Al Baik has been confirmed and is being prepared.',
      type: NotificationType.success,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Delivery on the Way',
      body: 'Your order from Panda Grocery is on the way. ETA: 15 min.',
      type: NotificationType.info,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: '3',
      title: 'New Offer Available',
      body: 'Get 20% off your next order from selected restaurants!',
      type: NotificationType.info,
      deepLink: '/market',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: '4',
      title: 'Service Reminder',
      body: 'Your AC maintenance appointment is tomorrow at 10 AM.',
      type: NotificationType.reminder,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AppNotification(
      id: '5',
      title: 'Welcome to Delwaqty',
      body: 'Explore restaurants, shops, and services all in one app.',
      type: NotificationType.info,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  @override
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  }) async {
    var filtered = List<AppNotification>.from(_notifications);

    if (unreadOnly == true) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (offset >= filtered.length) return [];
    final end = (offset + limit).clamp(0, filtered.length);
    return filtered.sublist(offset, end);
  }

  @override
  Future<int> getUnreadCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> clearAll() async {
    _notifications.clear();
  }
}
