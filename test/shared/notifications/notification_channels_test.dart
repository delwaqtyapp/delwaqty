import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/notifications/notification_channels.dart';

void main() {
  group('NotificationChannels.isAllowed', () {
    test('allows known customer routes', () {
      expect(
        NotificationChannels.isAllowed('/orders', isAdmin: false),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed('/wallet', isAdmin: false),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed('/notifications', isAdmin: false),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed('/campaign/c0f2e6a1-9f8d-4c2b-9a1e-1f2a3b4c5d6e', isAdmin: false),
        isTrue,
      );
    });

    test('matches parameterized room routes', () {
      expect(
        NotificationChannels.isAllowed('/support/room/abc-123', isAdmin: false),
        isTrue,
      );
    });

    test('admin-only routes require admin', () {
      expect(
        NotificationChannels.isAllowed('/admin/complaints', isAdmin: false),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed('/admin/complaints', isAdmin: true),
        isTrue,
      );
      expect(
        NotificationChannels.isAllowed('/admin/live-tracking', isAdmin: false),
        isFalse,
      );
      expect(
        NotificationChannels.isAllowed('/admin/support-chat/room/r1', isAdmin: true),
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
          NotificationChannels.isAllowed(route, isAdmin: true),
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
          NotificationChannels.isAllowed(route, isAdmin: true),
          isFalse,
          reason: 'should reject $route',
        );
      }
    });

    test('rejects unknown, empty and relative routes', () {
      expect(NotificationChannels.isAllowed('/admin/hacked', isAdmin: true), isFalse);
      expect(NotificationChannels.isAllowed('', isAdmin: true), isFalse);
      expect(NotificationChannels.isAllowed('orders', isAdmin: true), isFalse);
      expect(NotificationChannels.isAllowed('/orders/x/y', isAdmin: true), isFalse);
    });
  });
}
