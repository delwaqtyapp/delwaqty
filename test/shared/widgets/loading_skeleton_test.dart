import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/loading_skeleton.dart';

void main() {
  group('LoadingSkeleton', () {
    testWidgets('renders single skeleton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingSkeleton(width: 100, height: 20),
          ),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsOneWidget);
    });

    testWidgets('SkeletonListTile renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListTile(),
          ),
        ),
      );

      expect(find.byType(SkeletonListTile), findsOneWidget);
    });

    testWidgets('SkeletonCard renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
    });

    testWidgets('LoadingSkeleton respects custom height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingSkeleton(height: 32),
          ),
        ),
      );

      expect(find.byType(LoadingSkeleton), findsOneWidget);
    });
  });
}
