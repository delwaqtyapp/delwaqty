import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';

void main() {
  Widget buildTestWidget({
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isExpanded = false,
    AppButtonVariant variant = AppButtonVariant.filled,
    String buttonText = 'Test Button',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AppButton(
          onPressed: onPressed,
          isLoading: isLoading,
          isExpanded: isExpanded,
          variant: variant,
          child: Text(buttonText),
        ),
      ),
    );
  }

  group('AppButton', () {
    testWidgets('renders child text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(onPressed: () => tapped = true),
      );
      await tester.tap(find.byType(AppButton));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onPressed when isLoading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          onPressed: () => tapped = true,
          isLoading: true,
        ),
      );
      await tester.tap(find.byType(AppButton));
      expect(tapped, isFalse);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(buildTestWidget(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test Button'), findsNothing);
    });

    testWidgets('renders filled variant by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders outlined variant', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(variant: AppButtonVariant.outlined),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders text variant', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(variant: AppButtonVariant.text),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('expands to full width when isExpanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              onPressed: () {},
              isExpanded: true,
              child: const Text('Expanded'),
            ),
          ),
        ),
      );
      // The button should be wrapped in a SizedBox with width: double.infinity
      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(ElevatedButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, double.infinity);
    });
  });
}
