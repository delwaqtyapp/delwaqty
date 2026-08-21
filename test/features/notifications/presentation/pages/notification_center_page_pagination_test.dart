import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/domain/repositories/notification_repository.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/_shared/notifications/presentation/pages/notification_center_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _PagedRepository extends MockNotificationRepository {
  _PagedRepository(this.items);

  final List<AppNotification> items;

  @override
  Future<List<AppNotification>> getNotifications({
    bool? unreadOnly,
    int limit = 20,
    int offset = 0,
  }) async {
    final filtered = unreadOnly == true
        ? items.where((n) => !n.isRead).toList()
        : items;
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= filtered.length) return [];
    final end = (offset + limit).clamp(0, filtered.length);
    return filtered.sublist(offset, end);
  }
}

Widget _buildTestApp(NotificationRepository repo) {
  return ProviderScope(
    overrides: [
      notificationRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: NotificationCenterPage(),
    ),
  );
}

void main() {
  testWidgets('loads the first page then shows a load-more control', (
    tester,
  ) async {
    final now = DateTime.now();
    final repo = _PagedRepository(
      List.generate(25, (i) {
        return AppNotification(
          id: '$i',
          title: 'Notification $i',
          body: 'Body $i',
          type: NotificationType.info,
          createdAt: now.subtract(Duration(minutes: i)),
        );
      }),
    );

    await tester.pumpWidget(_buildTestApp(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Load more'), 400);
    expect(find.text('Load more'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('tapping load-more appends the next page', (tester) async {
    final now = DateTime.now();
    final repo = _PagedRepository(
      List.generate(25, (i) {
        return AppNotification(
          id: '$i',
          title: 'Notification $i',
          body: 'Body $i',
          type: NotificationType.info,
          createdAt: now.subtract(Duration(minutes: i)),
        );
      }),
    );

    await tester.pumpWidget(_buildTestApp(repo));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Load more'), 400);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Load more'), findsNothing);
    await tester.scrollUntilVisible(find.text('Notification 24'), 400);
    expect(find.text('Notification 24'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('high priority notification renders the priority chip', (
    tester,
  ) async {
    final repo = _PagedRepository([
      AppNotification(
        id: 'sos-1',
        title: 'SOS Alert',
        body: 'Emergency in your area',
        type: NotificationType.security,
        priority: NotificationPriority.high,
        createdAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(_buildTestApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('SOS Alert'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
  });
}
