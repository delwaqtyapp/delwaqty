import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('NotificationType', () {
    test('enum has all values', () {
      expect(NotificationType.values.length, 4);
      expect(NotificationType.info.name, 'info');
      expect(NotificationType.warning.name, 'warning');
      expect(NotificationType.success.name, 'success');
      expect(NotificationType.reminder.name, 'reminder');
    });
  });

  group('AppNotification', () {
    test('fromJson creates AppNotification from JSON', () {
      final json = {
        'id': 'n1',
        'title': 'Order Delivered',
        'body': 'Your order has been delivered successfully',
        'type': 'success',
        'isRead': false,
        'deepLink': '/orders/order1',
        'createdAt': now.toIso8601String(),
      };

      final notification = AppNotification.fromJson(json);
      expect(notification.id, 'n1');
      expect(notification.title, 'Order Delivered');
      expect(notification.body, 'Your order has been delivered successfully');
      expect(notification.type, NotificationType.success);
      expect(notification.isRead, false);
      expect(notification.deepLink, '/orders/order1');
    });

    test('toJson serializes correctly', () {
      final notification = AppNotification(
        id: 'n1',
        title: 'Promo',
        body: 'Get 10% off',
        type: NotificationType.info,
        createdAt: now,
      );

      final json = notification.toJson();
      expect(json['id'], 'n1');
      expect(json['title'], 'Promo');
      expect(json['type'], 'info');
      expect(json['isRead'], false);
      expect(json['deepLink'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AppNotification(
        id: 'n1',
        title: 'Warning',
        body: 'Low balance',
        type: NotificationType.warning,
        isRead: true,
        deepLink: '/wallet',
        createdAt: now,
      );

      final restored = AppNotification.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = AppNotification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        type: NotificationType.info,
        createdAt: now,
      );
      final b = AppNotification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        type: NotificationType.info,
        createdAt: now,
      );
      final c = AppNotification(
        id: 'n2',
        title: 'Other',
        body: 'Other body',
        type: NotificationType.reminder,
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final notification = AppNotification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        type: NotificationType.info,
        createdAt: now,
      );

      final updated = notification.copyWith(
        isRead: true,
        title: 'Updated Title',
      );
      expect(updated.isRead, true);
      expect(updated.title, 'Updated Title');
      expect(updated.id, 'n1');
      expect(updated.type, NotificationType.info);
      expect(notification.isRead, false);
    });

    test('defaults are applied correctly', () {
      final notification = AppNotification(
        id: 'n1',
        title: 'Title',
        body: 'Body',
        type: NotificationType.info,
        createdAt: now,
      );

      expect(notification.isRead, false);
      expect(notification.deepLink, isNull);
    });
  });
}
