import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_push_notifications_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
