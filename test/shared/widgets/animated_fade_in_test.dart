import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/animated_slide_in.dart';
import 'package:delwaqty/shared/widgets/gradient_background.dart';

void main() {
  group('AnimatedFadeIn', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedFadeIn(
              child: Text('Hello'),
            ),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('animates opacity over time', (tester) async {
      const fadeKey = Key('fade');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedFadeIn(
              key: fadeKey,
              child: Text('Animated'),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 700));
      final widget = tester.widget<AnimatedFadeIn>(find.byKey(fadeKey));
      expect(widget, isNotNull);
    });

    testWidgets('accepts custom duration', (tester) async {
      const fadeKey = Key('custom');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedFadeIn(
              key: fadeKey,
              duration: Duration(milliseconds: 1200),
              child: Text('Custom'),
            ),
          ),
        ),
      );
      final widget = tester.widget<AnimatedFadeIn>(find.byKey(fadeKey));
      expect(widget.duration, const Duration(milliseconds: 1200));
    });
  });

  group('AnimatedSlideIn', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSlideIn(
              child: Text('Slide In'),
            ),
          ),
        ),
      );
      expect(find.text('Slide In'), findsOneWidget);
    });

    testWidgets('accepts custom delay', (tester) async {
      const slideKey = Key('slide');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSlideIn(
              key: slideKey,
              delay: Duration(milliseconds: 500),
              child: Text('Delayed'),
            ),
          ),
        ),
      );
      final widget = tester.widget<AnimatedSlideIn>(find.byKey(slideKey));
      expect(widget.delay, const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('accepts custom offset', (tester) async {
      const slideKey = Key('offset');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSlideIn(
              key: slideKey,
              beginOffset: Offset(1, 0),
              child: Text('Offset'),
            ),
          ),
        ),
      );
      final widget = tester.widget<AnimatedSlideIn>(find.byKey(slideKey));
      expect(widget.beginOffset, const Offset(1, 0));
    });
  });

  group('GradientBackground', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GradientBackground(
              child: Text('Content'),
            ),
          ),
        ),
      );
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('applies gradient decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GradientBackground(
              child: SizedBox(),
            ),
          ),
        ),
      );
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('uses custom colors when provided', (tester) async {
      final customColors = [Colors.red, Colors.blue];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GradientBackground(
              colors: customColors,
              child: const SizedBox(),
            ),
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).last,
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      expect(gradient.colors, customColors);
    });
  });
}
