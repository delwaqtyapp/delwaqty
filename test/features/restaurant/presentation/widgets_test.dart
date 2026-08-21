import 'package:delwaqty/features/customer/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/restaurant_settings.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/widgets/offer_banner_card.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/widgets/service_type_chips.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrapInApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('ServiceTypeChips', () {
    testWidgets('shows all three chips when all enabled', (tester) async {
      final settings = RestaurantSettings(
        id: 'rs1',
        merchantId: 'm1',
        createdAt: DateTime(2025),
      );

      await tester.pumpWidget(wrapInApp(ServiceTypeChips(settings: settings)));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delivery_dining_rounded), findsOneWidget);
    });

    testWidgets('hides delivery when hasDelivery is false', (tester) async {
      final settings = RestaurantSettings(
        id: 'rs1',
        merchantId: 'm1',
        hasDelivery: false,
        createdAt: DateTime(2025),
      );

      await tester.pumpWidget(wrapInApp(ServiceTypeChips(settings: settings)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delivery_dining_rounded), findsNothing);
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsOneWidget);
    });

    testWidgets('hides takeaway when hasTakeaway is false', (tester) async {
      final settings = RestaurantSettings(
        id: 'rs1',
        merchantId: 'm1',
        hasTakeaway: false,
        hasDelivery: false,
        createdAt: DateTime(2025),
      );

      await tester.pumpWidget(wrapInApp(ServiceTypeChips(settings: settings)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsNothing);
      expect(find.byIcon(Icons.delivery_dining_rounded), findsNothing);
    });

    testWidgets('shows only delivery when only hasDelivery is true', (tester) async {
      final settings = RestaurantSettings(
        id: 'rs1',
        merchantId: 'm1',
        hasDineIn: false,
        hasTakeaway: false,
        createdAt: DateTime(2025),
      );

      await tester.pumpWidget(wrapInApp(ServiceTypeChips(settings: settings)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delivery_dining_rounded), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
      expect(find.byIcon(Icons.takeout_dining_rounded), findsNothing);
    });
  });

  group('OfferBannerCard', () {
    testWidgets('displays offer title', (tester) async {
      final offer = Offer(
        id: 'o1',
        merchantId: 'm1',
        title: '20% Off Everything',
        discountValue: 20.0,
        minimumOrder: 15.0,
        createdAt: DateTime(2025, 6, 15),
      );

      await tester.pumpWidget(wrapInApp(
        SizedBox(width: 300, child: OfferBannerCard(offer: offer)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('20% Off Everything'), findsOneWidget);
    });

    testWidgets('displays fixed discount title', (tester) async {
      final offer = Offer(
        id: 'o2',
        merchantId: 'm1',
        title: '5 EGP Off',
        discountType: 'fixed',
        discountValue: 5.0,
        minimumOrder: 20.0,
        createdAt: DateTime(2025, 6, 15),
      );

      await tester.pumpWidget(wrapInApp(
        SizedBox(width: 300, child: OfferBannerCard(offer: offer)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('5 EGP Off'), findsOneWidget);
    });

    testWidgets('shows minimum order when > 0', (tester) async {
      final offer = Offer(
        id: 'o3',
        merchantId: 'm1',
        title: 'Deal',
        discountValue: 10.0,
        minimumOrder: 25.0,
        createdAt: DateTime(2025, 6, 15),
      );

      await tester.pumpWidget(wrapInApp(
        SizedBox(width: 300, child: OfferBannerCard(offer: offer)),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OfferBannerCard), findsOneWidget);
    });

    testWidgets('hides minimum order when 0', (tester) async {
      final offer = Offer(
        id: 'o4',
        merchantId: 'm1',
        title: 'Free Item',
        discountValue: 100.0,
        createdAt: DateTime(2025, 6, 15),
      );

      await tester.pumpWidget(wrapInApp(
        SizedBox(width: 300, child: OfferBannerCard(offer: offer)),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OfferBannerCard), findsOneWidget);
    });
  });
}
