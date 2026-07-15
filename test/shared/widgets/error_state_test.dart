import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';

void main() {
  group('ErrorState', () {
    testWidgets('displays error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'Something went wrong',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('calls onRetry when tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'Error occurred',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });

    testWidgets('renders without retry button when onRetry null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorState(
              message: 'Error',
            ),
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });
}
