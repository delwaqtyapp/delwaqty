import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('displays title and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No expenses',
              message: 'Start tracking your spending',
              icon: Icons.receipt_long,
            ),
          ),
        ),
      );

      expect(find.text('No expenses'), findsOneWidget);
      expect(find.text('Start tracking your spending'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    });

    testWidgets('displays action button', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'No data',
              message: 'Add some items',
              icon: Icons.inbox,
              actionLabel: 'Add Item',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Add Item'), findsOneWidget);
      await tester.tap(find.text('Add Item'));
      expect(tapped, true);
    });
  });
}
