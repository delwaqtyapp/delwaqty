import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/error_widget.dart';

void main() {
  Widget buildTestWidget({
    required String message,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AppErrorWidget(
          message: message,
          onRetry: onRetry,
        ),
      ),
    );
  }

  group('AppErrorWidget', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(message: 'Something went wrong'),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders error icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(message: 'Error'));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('does not render retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(message: 'Error'));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders retry button when onRetry is provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          message: 'Error',
          onRetry: () {},
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is tapped', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        buildTestWidget(
          message: 'Error',
          onRetry: () => retried = true,
        ),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('renders with padding', (tester) async {
      await tester.pumpWidget(buildTestWidget(message: 'Error'));
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byType(Column),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(24));
    });
  });
}
