import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';

void main() {
  group('NotificationChannels.isAllowed', () {
    test('allows known customer routes', () {
      expect(
        NotificationChannels.isAllowed('/orders', context: AppContext.customer),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed('/wallet', context: AppContext.customer),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed(
          '/notifications',
          context: AppContext.customer,
        ),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed(
          '/campaign/c0f2e6a1-9f8d-4c2b-9a1e-1f2a3b4c5d6e',
          context: AppContext.customer,
        ),
        isTrue,
      );
    });

    test('matches parameterized room routes', () {
      expect(
        NotificationChannels.isAllowed(
          '/support/room/abc-123',
          context: AppContext.customer,
        ),
        isTrue,
      );
    });

    test('admin-only routes require admin context', () {
      expect(
        NotificationChannels.isAllowed(
          '/admin/complaints',
          context: AppContext.customer,
        ),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed(
          '/admin/complaints',
          context: AppContext.admin,
        ),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed(
          '/admin/live-tracking',
          context: AppContext.customer,
        ),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed(
          '/admin/support-chat/room/r1',
          context: AppContext.admin,
        ),
        isTrue,
      );
    });

    test('provider routes are scoped to provider context', () {
      expect(
        NotificationChannels.isAllowed(
          '/provider-availability',
          context: AppContext.customer,
        ),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed(
          '/provider-availability',
          context: AppContext.provider,
        ),
        isTrue,
      );
    });

    test('rejects scheme injection', () {
      for (final route in [
        '/javascript:alert(1)',
        '/http://evil.com',
        '/https://evil.com',
        '/data:text/html,base64',
        '/vbscript:x',
        '/file:///etc/passwd',
      ]) {
        expect(
          NotificationChannels.isAllowed(route, context: AppContext.admin),
          isFalse,
          reason: 'should reject $route',
        );
      }
    });

    test('rejects path traversal', () {
      for (final route in [
        '/orders/../admin',
        '/../profile',
        '/orders/./profile',
        '/admin/../orders',
      ]) {
        expect(
          NotificationChannels.isAllowed(route, context: AppContext.admin),
          isFalse,
          reason: 'should reject $route',
        );
      }
    });

    test('rejects unknown, empty and relative routes', () {
      expect(
        NotificationChannels.isAllowed('/admin/hacked', context: AppContext.admin),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed('', context: AppContext.admin),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed('orders', context: AppContext.admin),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed('/orders/x/y', context: AppContext.admin),
        isFalse,
      );
    });
  });
}
