import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/widgets/open_status_badge.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkingHours row(int day, String open, String close) => WorkingHours(
    id: 'wh-$day',
    merchantId: 'm1',
    dayOfWeek: day,
    openTime: open,
    closeTime: close,
    createdAt: DateTime(2026),
  );

  // Friday (5) overnight 23:00-01:00, Saturday (6) same-day 12:00-23:00.
  final schedule = [row(5, '23:00', '01:00'), row(6, '12:00', '23:00')];

  // Cairo is UTC+2 in November 2026; these are UTC instants.
  var fakeNow = DateTime.utc(2026, 11, 20, 22, 30); // Sat 00:30 Cairo

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: OpenStatusBadge(
            manualOpen: true,
            hours: schedule,
            clock: () => fakeNow,
            tick: const Duration(seconds: 1),
          ),
        ),
      ),
    );
  }

  testWidgets('badge stays fresh across an overnight close and the next '
      'opening while the page stays mounted', (tester) async {
    await mount(tester);
    // Friday's overnight window still serves at 00:30 Saturday.
    expect(find.text('Open'), findsOneWidget);

    // Cross the 01:00 Cairo close with the page mounted: the tick must
    // re-evaluate without any rebuild from the parent.
    fakeNow = DateTime.utc(2026, 11, 20, 23, 30); // Sat 01:30 Cairo
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Closed'), findsOneWidget);

    // Cross into Saturday's 12:00 opening: still the same mounted widget.
    fakeNow = DateTime.utc(2026, 11, 21, 10, 30); // Sat 12:30 Cairo
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('manual flag off stays closed even inside the window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: OpenStatusBadge(
            manualOpen: false,
            hours: schedule,
            clock: () => fakeNow,
            tick: const Duration(seconds: 1),
          ),
        ),
      ),
    );
    expect(find.text('Closed'), findsOneWidget);
  });

  testWidgets('no schedule means the manual flag alone decides', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: OpenStatusBadge(
            manualOpen: true,
            hours: const [],
            clock: () => fakeNow,
            tick: const Duration(seconds: 1),
          ),
        ),
      ),
    );
    expect(find.text('Open'), findsOneWidget);
  });
}
