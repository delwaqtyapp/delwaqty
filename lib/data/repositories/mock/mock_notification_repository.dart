import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: 'Budget Alert',
      body: 'You have spent 80% of your Groceries budget this month.',
      type: NotificationType.warning,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Expense Added',
      body: 'Your expense of \$85.50 for Grocery Shopping has been recorded.',
      type: NotificationType.success,
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    AppNotification(
      id: '3',
      title: 'Monthly Report',
      body: 'Your monthly financial report for June is ready.',
      type: NotificationType.info,
      deepLink: '/reports/june',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: '4',
      title: 'Bill Reminder',
      body: 'Your electric bill is due in 3 days.',
      type: NotificationType.reminder,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AppNotification(
      id: '5',
      title: 'Welcome to Delwaqty',
      body: 'Start tracking your expenses and achieve your financial goals.',
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
    _notifications.clear();
    _notifications.addAll(
      _notifications.map((n) => n.copyWith(isRead: true)),
    );
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
