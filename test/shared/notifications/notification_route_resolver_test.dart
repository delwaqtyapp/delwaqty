import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

void main() {
  group('NotificationRouteResolver', () {
    test('resolve returns the deep link when allowed', () {
      expect(
        NotificationRouteResolver.resolve(deepLink: '/orders'),
        '/orders',
      );
      expect(
        NotificationRouteResolver.resolve(
          deepLink: '/admin/complaints',
          isAdmin: true,
        ),
        '/admin/complaints',
      );
    });

    test('resolve returns null when disallowed or empty', () {
      expect(NotificationRouteResolver.resolve(), isNull);
      expect(NotificationRouteResolver.resolve(deepLink: ''), isNull);
      expect(
        NotificationRouteResolver.resolve(deepLink: '/javascript:alert(1)'),
        isNull,
      );
      expect(
        NotificationRouteResolver.resolve(deepLink: '/admin/complaints'),
        isNull,
      );
    });

    test('safe falls back to /notifications', () {
      expect(NotificationRouteResolver.safe(), '/notifications');
      expect(
        NotificationRouteResolver.safe(deepLink: '/javascript:alert(1)'),
        '/notifications',
      );
      expect(
        NotificationRouteResolver.safe(deepLink: '/admin/complaints'),
        '/notifications',
      );
    });

    test('safePayload resolves from the payload and falls back', () {
      const payload = NotificationPayload(deepLink: '/wallet');
      expect(NotificationRouteResolver.safePayload(payload), '/wallet');

      const empty = NotificationPayload();
      expect(NotificationRouteResolver.safePayload(empty), '/notifications');
    });
  });
}
