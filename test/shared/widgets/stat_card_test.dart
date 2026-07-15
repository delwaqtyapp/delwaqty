import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/stat_card.dart';

void main() {
  group('StatCard', () {
    testWidgets('displays title and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Total',
              value: '\$1,234',
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('\$1,234'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });

    testWidgets('displays trend indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Income',
              value: '\$5,000',
              icon: Icons.trending_up,
              color: Colors.green,
              trend: '+12%',
              trendIsPositive: true,
            ),
          ),
        ),
      );

      expect(find.text('+12%'), findsOneWidget);
    });

    testWidgets('displays negative trend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Expenses',
              value: '\$2,000',
              icon: Icons.trending_down,
              color: Colors.red,
              trend: '-5%',
              trendIsPositive: false,
            ),
          ),
        ),
      );

      expect(find.text('-5%'), findsOneWidget);
    });

    testWidgets('displays subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              title: 'Balance',
              value: '\$3,000',
              subtitle: 'Last 30 days',
            ),
          ),
        ),
      );

      expect(find.text('Last 30 days'), findsOneWidget);
    });
  });
}
