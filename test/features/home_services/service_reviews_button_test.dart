import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/presentation/widgets/service_reviews_button.dart';

void main() {
  group('ServiceReviewsButton (unified reviews entry)', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: ServiceReviewsButton(
                categoryType: ServiceCategoryType.doctor,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the unified gold star icon with rateService tooltip',
        (tester) async {
      await pump(tester);
      expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
      expect(find.byType(ServiceReviewsButton), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}