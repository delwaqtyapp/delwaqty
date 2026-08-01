import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/mock/mock_notification_repository.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/features/notifications/presentation/pages/notification_center_page.dart';
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

void main() {
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
