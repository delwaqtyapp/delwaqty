import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/section_header.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('displays title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Recent'),
          ),
        ),
      );

      expect(find.text('Recent'), findsOneWidget);
    });

    testWidgets('displays action label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Categories',
              actionLabel: 'See All',
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('See All'), findsOneWidget);
    });

    testWidgets('calls onAction when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Categories',
              actionLabel: 'See All',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('See All'));
      expect(tapped, true);
    });
  });
}
