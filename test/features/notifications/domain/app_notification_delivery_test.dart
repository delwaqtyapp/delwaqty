import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

void main() {
  final now = DateTime(2026, 8, 15);

  group('NotificationPriority', () {
    test('enum has all values', () {
      expect(NotificationPriority.values.length, 3);
      expect(NotificationPriority.low.name, 'low');
      expect(NotificationPriority.normal.name, 'normal');
      expect(NotificationPriority.high.name, 'high');
    });
  });

  group('NotificationPushStatus', () {
    test('enum has all values', () {
      expect(NotificationPushStatus.values.length, 4);
      expect(NotificationPushStatus.pending.name, 'pending');
      expect(NotificationPushStatus.sent.name, 'sent');
      expect(NotificationPushStatus.failed.name, 'failed');
      expect(NotificationPushStatus.unconfigured.name, 'unconfigured');
    });
  });

  group('AppNotification delivery fields', () {
    test('priority and pushStatus default to normal/pending', () {
      final notification = AppNotification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        type: NotificationType.info,
        createdAt: now,
      );

      expect(notification.priority, NotificationPriority.normal);
      expect(notification.pushStatus, NotificationPushStatus.pending);
      expect(notification.senderId, isNull);
    });

    test('fromJson maps priority, sender_id and push_status', () {
      final json = {
        'id': 'n1',
        'title': 'SOS',
        'body': 'Emergency alert',
        'type': 'security',
        'priority': 'high',
        'senderId': 'admin-1',
        'pushStatus': 'failed',
        'createdAt': now.toIso8601String(),
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.priority, NotificationPriority.high);
      expect(notification.senderId, 'admin-1');
      expect(notification.pushStatus, NotificationPushStatus.failed);
    });

    test('json roundtrip preserves delivery fields', () {
      final original = AppNotification(
        id: 'n1',
        title: 'Offer',
        body: '20% off',
        type: NotificationType.promotion,
        priority: NotificationPriority.high,
        senderId: 'admin-1',
        pushStatus: NotificationPushStatus.sent,
        createdAt: now,
      );

      final restored = AppNotification.fromJson(original.toJson());

      expect(restored.priority, NotificationPriority.high);
      expect(restored.senderId, 'admin-1');
      expect(restored.pushStatus, NotificationPushStatus.sent);
      expect(restored, original);
    });
  });

  group('NotificationPayload.resolveDeepLink', () {
    test('prefers the explicit deep_link', () {
      const payload = NotificationPayload(
        deepLink: '/orders',
        entityType: 'campaign',
        entityId: 'abc',
      );

      expect(payload.resolveDeepLink(), '/orders');
    });

    test('falls back to the entity default route', () {
      const payload = NotificationPayload(
        entityType: 'order',
        entityId: 'order-1',
      );

      expect(payload.resolveDeepLink(), '/market/orders/order-1');
    });

    test('returns null when no deep link or entity exists', () {
      const payload = NotificationPayload();
      expect(payload.resolveDeepLink(), isNull);
    });
  });
}
