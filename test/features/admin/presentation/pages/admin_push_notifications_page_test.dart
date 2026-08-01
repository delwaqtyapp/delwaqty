import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_push_notifications_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeDeviceStats', () {
    final now = DateTime.now();

    test('counts recently seen tokens as online', () {
      final tokens = [
        {'updated_at': now.subtract(const Duration(minutes: 2)).toIso8601String()},
        {'updated_at': now.subtract(const Duration(hours: 1)).toIso8601String()},
      ];

      final stats = computeDeviceStats(tokens, now);

      expect(stats.online, 1);
      expect(stats.offline, 1);
    });

    test('treats missing updated_at as offline', () {
      final stats = computeDeviceStats([
        {'token': 'abc'},
      ], now);

      expect(stats.online, 0);
      expect(stats.offline, 1);
    });

    test('token seen exactly at the window boundary is online', () {
      final tokens = [
        {'updated_at': now.subtract(onlineWindow).toIso8601String()},
      ];

      final stats = computeDeviceStats(tokens, now);

      expect(stats.online, 1);
      expect(stats.offline, 0);
    });

    test('empty token list yields zero counters', () {
      final stats = computeDeviceStats(const [], now);

      expect(stats.online, 0);
      expect(stats.offline, 0);
    });
  });

  group('buildBroadcastParams', () {
    test('broadcasts to all users by default', () {
      final params = buildBroadcastParams(
        title: 'title',
        body: 'body',
        type: NotificationType.info,
      );

      expect(params['p_title'], 'title');
      expect(params['p_body'], 'body');
      expect(params['p_type'], 'info');
      expect(params['p_deep_link'], isNull);
      expect(params['p_target_role'], isNull);
      expect(params['p_target_user_id'], isNull);
    });

    test('maps role audience to p_target_role', () {
      final params = buildBroadcastParams(
        title: 'title',
        body: 'body',
        type: NotificationType.warning,
        audience: 'driver',
      );

      expect(params['p_type'], 'warning');
      expect(params['p_target_role'], 'driver');
      expect(params['p_target_user_id'], isNull);
    });

    test('trims and keeps deep link', () {
      final params = buildBroadcastParams(
        title: 'title',
        body: 'body',
        type: NotificationType.success,
        deepLink: '  /order/123  ',
      );

      expect(params['p_deep_link'], '/order/123');
      expect(params['p_type'], 'success');
    });

    test('treats blank deep link as absent', () {
      final params = buildBroadcastParams(
        title: 'title',
        body: 'body',
        type: NotificationType.reminder,
        deepLink: '   ',
      );

      expect(params['p_deep_link'], isNull);
      expect(params['p_type'], 'reminder');
    });
  });
}
