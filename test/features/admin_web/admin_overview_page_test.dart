import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_overview_page.dart';
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
      child: const MaterialApp(home: Scaffold(body: AdminOverviewPage())),
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
        child: const MaterialApp(home: Scaffold(body: AdminOverviewPage())),
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
    await tester.pumpWidget(pumpApp(error: Exception('db down')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load dashboard stats'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}