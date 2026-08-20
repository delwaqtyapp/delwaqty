import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(MockNotificationRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Repository providers', () {
    test('notificationRepositoryProvider returns MockNotificationRepository', () {
      final repo = container.read(notificationRepositoryProvider);
      expect(repo, isA<MockNotificationRepository>());
    });

    test('notificationsProvider returns list of notifications', () async {
      final notifications = await container.read(notificationsProvider.future);
      expect(notifications, isNotEmpty);
    });

    test('unreadCountProvider returns count', () async {
      final count = await container.read(unreadCountProvider.future);
      expect(count, greaterThanOrEqualTo(0));
    });
  });
}
