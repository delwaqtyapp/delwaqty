import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_overview_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_overview.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_overview_providers.dart';

void main() {
  const stats = AdminOverviewStats(
    users: 1200,
    merchants: 85,
    orders: 3400,
    drivers: 12,
    serviceBookings: 640,
  );

  Widget pumpApp({Object? error, Future<void> Function()? onRefreshCalled}) {
    return ProviderScope(
      overrides: [
        adminOverviewStatsProvider.overrideWith((ref) async {
          if (error != null) throw error;
          return stats;
        }),
      ],
      child: const MaterialApp(
        // The page's error state goes through appErrorText(), so the harness
        // must provide the delegates exactly as the real app does.
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: Scaffold(body: AdminOverviewPage()),
      ),
    );
  }

  testWidgets('renders the KPI cards with live counters', (tester) async {
    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('Total Merchants'), findsOneWidget);
    expect(find.text('Service Bookings'), findsOneWidget);
  });

  testWidgets('shows a loading state before data arrives', (tester) async {
    final completer = Completer<AdminOverviewStats>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminOverviewStatsProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: Scaffold(body: AdminOverviewPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(stats);
    await tester.pumpAndSettle();
    expect(find.text('1200'), findsOneWidget);
  });

  testWidgets('shows an error state with retry when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      // A stand-in with the same shape as a PostgREST failure: a code the
      // classifier can read and a message full of Postgres detail.
      pumpApp(
        error: _FakePostgrestException(
          'function public.get_commission_rate(text, unknown) is not unique',
          '42725',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The operator gets a localized sentence plus a retry, and the Postgres text
    // - SQLSTATE, function name and all - never reaches the screen. 42725 is a
    // server-side fault, so the classifier picks the server sentence rather than
    // the catch-all.
    expect(find.text('A server error occurred. Please try again shortly.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('get_commission_rate'), findsNothing);
    expect(find.textContaining('42725'), findsNothing);
  });
}

/// Mirrors the PostgREST exception surface the classifier inspects (`code` and
/// `message`) without pulling the transitive package into the test target.
class _FakePostgrestException implements Exception {
  _FakePostgrestException(this.message, this.code);

  final String message;
  final String code;

  @override
  String toString() => 'PostgrestException(message: $message, code: $code)';
}
