import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/utils/page_transitions.dart';

void main() {
  group('AppPageTransitions', () {
    test('fadeSlide creates a PageRouteBuilder', () {
      final route = AppPageTransitions.fadeSlide<int>(
        const Text('page'),
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('slideFromRight creates a PageRouteBuilder', () {
      final route = AppPageTransitions.slideFromRight<int>(
        const Text('page'),
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('slideFromBottom creates a PageRouteBuilder', () {
      final route = AppPageTransitions.slideFromBottom<int>(
        const Text('page'),
      );
      expect(route, isA<PageRouteBuilder>());
    });

    test('scaleFade creates a PageRouteBuilder', () {
      final route = AppPageTransitions.scaleFade<int>(
        const Text('page'),
      );
      expect(route, isA<PageRouteBuilder>());
    });

    testWidgets('fadeSlide transition animates', (tester) async {
      final route = AppPageTransitions.fadeSlide<int>(
        const Text('target'),
      );

      await tester.pumpWidget(MaterialApp(home: Navigator(
        onGenerateRoute: (_) => route,
      )));
      await tester.pumpAndSettle();
      expect(find.text('target'), findsOneWidget);
    });
  });
}
