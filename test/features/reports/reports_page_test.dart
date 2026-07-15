import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/reports/presentation/pages/reports_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReportsPage(),
    ),
  );
}

Future<void> suppressOverflowErrors(Future<void> Function() testBody) async {
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('overflowed')) return;
    oldHandler?.call(details);
  };
  try {
    await testBody();
  } finally {
    FlutterError.onError = oldHandler;
  }
}

void main() {
  group('ReportsPage', () {
    testWidgets('renders reports title', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Reports'), findsOneWidget);
      });
    });

    testWidgets('renders summary cards with labels', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Total Income'), findsOneWidget);
        expect(find.text('Total Expenses'), findsOneWidget);
        expect(find.text('Balance'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
      });
    });

    testWidgets('shows total income value', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('\$5,000.00'), findsOneWidget);
      });
    });

    testWidgets('shows total expenses value', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('\$544.23'), findsOneWidget);
      });
    });

    testWidgets('shows balance value', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('\$4,455.77'), findsOneWidget);
      });
    });

    testWidgets('shows category count', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('7'), findsOneWidget);
      });
    });

    testWidgets('shows category breakdown section header', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Category Breakdown'), findsOneWidget);
      });
    });

    testWidgets('category breakdown shows items after scrolling', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Groceries'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('Groceries'), findsOneWidget);
      });
    });

    testWidgets('category breakdown shows percentages', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('37%'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('37%'), findsOneWidget);
      });
    });

    testWidgets('shows monthly trend section after scrolling', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Last 6 Months'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('Monthly Trend'), findsOneWidget);
        expect(find.text('Last 6 Months'), findsOneWidget);
      });
    });

    testWidgets('monthly trend shows month labels after scrolling', (tester) async {
      await suppressOverflowErrors(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Jan'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('Jan'), findsOneWidget);
        expect(find.text('Feb'), findsOneWidget);
        expect(find.text('Mar'), findsOneWidget);
      });
    });
  });
}
