import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/app_search_bar.dart';

void main() {
  group('AppSearchBar', () {
    testWidgets('displays hint text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchBar(
              hint: 'Search expenses',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Search expenses'), findsOneWidget);
    });

    testWidgets('calls onChanged when typing', (tester) async {
      String value = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchBar(
              hint: 'Search',
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      expect(value, 'test');
    });

    testWidgets('clear button clears text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AppSearchBar(
                controller: controller,
                hint: 'Search',
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, '');
    });
  });
}
