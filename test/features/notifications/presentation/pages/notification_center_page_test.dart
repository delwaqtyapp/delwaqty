import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/_shared/notifications/presentation/pages/notification_center_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(
        MockNotificationRepository(),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: NotificationCenterPage(),
    ),
  );
}

/// One unread OTA announcement; records markAsRead calls (#48).
class _OtaNotificationRepository implements NotificationRepository {
  AppNotification ota = AppNotification(
    id: 'ota-1',
    title: 'Update available',
    body: '1.0.5 is ready',
    type: NotificationType.otaUpdate,
    deepLink: '/settings/about',
    createdAt: DateTime.now(),
  );
  final markedRead = <String>[];

  @override
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  }) async => offset == 0 ? [ota] : const [];

  @override
  Future<int> getUnreadCount() async => ota.isRead ? 0 : 1;

  @override
  Future<void> markAsRead(String id) async {
    markedRead.add(id);
    ota = ota.copyWith(isRead: true);
  }

  @override
  Future<BulkNotificationResult> markAllAsRead() async {
    await markAsRead(ota.id);
    return const BulkNotificationResult(completed: true, processed: 1);
  }

  @override
  Future<void> deleteNotification(String id) async {}

  @override
  Future<BulkNotificationResult> clearAll() async =>
      const BulkNotificationResult(completed: true, processed: 0);

  @override
  Future<bool> existsByIdempotencyKey(String key) async => false;

  @override
  Future<void> deactivateDeviceTokens(String deviceId) async {}
}

void main() {
  testWidgets('tapping an OTA announcement marks it read and clears the '
      'unread dot (#48)', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'delwaqty',
      packageName: 'app.delwaqty.customer',
      version: '1.0.4',
      buildNumber: '5',
      buildSignature: '',
    );
    final repo = _OtaNotificationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: NotificationCenterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Unread indicator is visible before the tap.
    expect(find.text('Update available'), findsOneWidget);
    expect(repo.ota.isRead, isFalse);

    await tester.tap(find.text('Update available'));
    await tester.pumpAndSettle();

    // The tap settles read state (previously skipped by the early return).
    expect(repo.markedRead, ['ota-1']);
    expect(repo.ota.isRead, isTrue);
    expect(await repo.getUnreadCount(), 0);
  });

  testWidgets('renders a delete button for every notification', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(5));
  });

  testWidgets('delete all removes every notification after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete all notifications?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(5));

    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('tapping a per-notification delete removes only that one', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(4));
  });
}
