import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/categories/presentation/pages/add_category_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AddCategoryPage()),
    ),
  );
}

void main() {
  group('AddCategoryPage', () {
    testWidgets('renders form fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Category Name'), findsOneWidget);
      expect(find.text('Select Icon'), findsOneWidget);
    });

    testWidgets('renders add category title', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Category'), findsWidgets);
    });

    testWidgets('renders save button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Category'), findsWidgets);
    });

    testWidgets('validation: empty name shows error', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final formState = tester.state<FormState>(find.byType(Form));
      formState.validate();
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('icon picker grid is present', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsWidgets);
    });

    testWidgets('category icons are displayed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.shopping_cart_rounded), findsWidgets);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
      expect(find.byIcon(Icons.restaurant_rounded), findsWidgets);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
    });

    testWidgets('budget field accepts numeric input', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final budgetField = find.byType(TextFormField).last;
      await tester.ensureVisible(budgetField);
      await tester.enterText(budgetField, '500');
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('name field accepts text input', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'New Category');
      expect(find.text('New Category'), findsOneWidget);
    });

    testWidgets('does not show delete button for new category', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
    });
  });
}
