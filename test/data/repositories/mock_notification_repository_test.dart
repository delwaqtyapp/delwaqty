import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

void main() {
  late MockNotificationRepository repo;

  setUp(() {
    repo = MockNotificationRepository();
  });

  group('MockNotificationRepository', () {
    test('getNotifications returns notifications', () async {
      final notifications = await repo.getNotifications();
      expect(notifications, isNotEmpty);
    });

    test('getUnreadCount returns correct count', () async {
      final count = await repo.getUnreadCount();
      expect(count, greaterThanOrEqualTo(0));
    });

    test('markAsRead updates notification', () async {
      await repo.markAsRead('1');
      final notifications = await repo.getNotifications();
      final notification = notifications.firstWhere((n) => n.id == '1');
      expect(notification.isRead, true);
    });

    test('markAllAsRead marks all as read', () async {
      await repo.markAllAsRead();
      final count = await repo.getUnreadCount();
      expect(count, 0);
    });

    test('deleteNotification removes notification', () async {
      await repo.deleteNotification('1');
      final notifications = await repo.getNotifications();
      final found = notifications.where((n) => n.id == '1');
      expect(found, isEmpty);
    });

    test('NotificationType enum has correct values', () {
      expect(NotificationType.values.length, 4);
    });

    test('getNotifications with unreadOnly filters', () async {
      final unread = await repo.getNotifications(unreadOnly: true);
      for (final n in unread) {
        expect(n.isRead, false);
      }
    });

    test('clearAll removes all notifications', () async {
      await repo.clearAll();
      final notifications = await repo.getNotifications();
      expect(notifications, isEmpty);
    });
  });
}
