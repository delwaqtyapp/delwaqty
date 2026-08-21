import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/product_card.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/price_tag.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/delivery_info.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_type_chip.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget wrapInApp(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: child,
        ),
      ),
    );

Merchant buildMerchant({
  String? name,
  MerchantType type = MerchantType.restaurant,
  double rating = 4.5,
  bool isOpenNow = true,
  bool isVerified = true,
  bool deliveryAvailable = true,
  int? estimatedDeliveryMinutes = 30,
  double? deliveryFee = 10.0,
}) =>
    Merchant(
      id: 'm1',
      name: name ?? 'Test Merchant',
      type: type,
      latitude: 24.7136,
      longitude: 46.6753,
      rating: rating,
      isOpenNow: isOpenNow,
      isVerified: isVerified,
      deliveryAvailable: deliveryAvailable,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes,
      deliveryFee: deliveryFee,
      createdAt: DateTime(2025),
    );

Product buildProduct({
  String? name,
  double price = 35.0,
  double? originalPrice,
  bool isAvailable = true,
}) =>
    Product(
      id: 'p1',
      merchantId: 'm1',
      categoryId: 'c1',
      name: name ?? 'Test Product',
      price: price,
      originalPrice: originalPrice,
      isAvailable: isAvailable,
      createdAt: DateTime(2025),
    );

void main() {
  group('MerchantCard', () {
    testWidgets('displays merchant name', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(name: 'Al Baik'),
        onTap: () {},
      )));

      expect(find.text('Al Baik'), findsOneWidget);
    });

    testWidgets('displays rating', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(),
        onTap: () {},
      )));

      expect(find.text('4.5'), findsOneWidget);
    });

    testWidgets('displays type label for restaurant', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(),
        onTap: () {},
      )));

      expect(find.text('Restaurant'), findsOneWidget);
    });

    testWidgets('displays type label for pharmacy', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(type: MerchantType.pharmacy),
        onTap: () {},
      )));

      expect(find.text('Pharmacy'), findsOneWidget);
    });

    testWidgets('shows Open badge when isOpenNow', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(),
        onTap: () {},
      )));

      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('hides Open badge when not open', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(isOpenNow: false),
        onTap: () {},
      )));

      expect(find.text('Open'), findsNothing);
    });

    testWidgets('shows Verified badge when verified', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(),
        onTap: () {},
      )));

      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('hides Verified badge when not verified', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(isVerified: false),
        onTap: () {},
      )));

      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('displays delivery info when delivery available', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(
          
        ),
        onTap: () {},
      )));

      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('10 ج.م'), findsOneWidget);
    });

    testWidgets('hides delivery info when not available', (tester) async {
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(deliveryAvailable: false),
        onTap: () {},
      )));

      expect(find.text('Delivery'), findsNothing);
      expect(find.byIcon(Icons.delivery_dining), findsNothing);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapInApp(MerchantCard(
        merchant: buildMerchant(),
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('ProductCard', () {
    testWidgets('displays product name', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(name: 'Chicken Meal'),
        onTap: () {},
      )));

      expect(find.text('Chicken Meal'), findsOneWidget);
    });

    testWidgets('displays price', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(),
        onTap: () {},
      )));

      expect(find.text('35 ج.م'), findsOneWidget);
    });

    testWidgets('displays discount badge when discounted', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(originalPrice: 50.0),
        onTap: () {},
      )));

      expect(find.text('-30%'), findsOneWidget);
    });

    testWidgets('hides discount badge when no originalPrice', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(),
        onTap: () {},
      )));

      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('shows unavailable overlay', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(isAvailable: false),
        onTap: () {},
      )));

      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('hides unavailable overlay when available', (tester) async {
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(),
        onTap: () {},
      )));

      expect(find.text('Unavailable'), findsNothing);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapInApp(ProductCard(
        product: buildProduct(),
        onTap: () => tapped = true,
      )));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });

  group('RatingStars', () {
    testWidgets('renders 5 star icons', (tester) async {
      await tester.pumpWidget(wrapInApp(const RatingStars(rating: 3.0)));

      expect(find.byIcon(Icons.star), findsWidgets);
      expect(find.byIcon(Icons.star_border), findsWidgets);
    });

    testWidgets('shows full stars for integer rating', (tester) async {
      await tester.pumpWidget(wrapInApp(const RatingStars(rating: 4.0)));

      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      expect(find.byIcon(Icons.star_half), findsNothing);
    });

    testWidgets('shows half star for fractional rating', (tester) async {
      await tester.pumpWidget(wrapInApp(const RatingStars(rating: 4.5)));

      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_half), findsOneWidget);
    });

    testWidgets('shows count when showCount is true', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RatingStars(rating: 4.5, showCount: true, count: 120),
      ));

      expect(find.text('4.5 (120)'), findsOneWidget);
    });

    testWidgets('hides count when showCount is false', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const RatingStars(rating: 4.5, count: 120),
      ));

      expect(find.text('4.5 (120)'), findsNothing);
    });

    testWidgets('respects size parameter', (tester) async {
      await tester.pumpWidget(wrapInApp(const RatingStars(rating: 3.0, size: 24)));

      final icon = tester.widget<Icon>(find.byIcon(Icons.star).first);
      expect(icon.size, 24);
    });
  });

  group('PriceTag', () {
    testWidgets('displays price with ج.م', (tester) async {
      await tester.pumpWidget(wrapInApp(const PriceTag(price: 35.0)));

      expect(find.text('35 ج.م'), findsOneWidget);
    });

    testWidgets('displays original price with strikethrough when discounted',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        const PriceTag(price: 35.0, originalPrice: 50.0),
      ));

      expect(find.text('35 ج.م'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('hides original price when no discount', (tester) async {
      await tester.pumpWidget(wrapInApp(const PriceTag(price: 35.0)));

      expect(find.text('35 ج.م'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('hides original price when originalPrice <= price',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        const PriceTag(price: 50.0, originalPrice: 50.0),
      ));

      expect(find.text('50 ج.م'), findsOneWidget);
      expect(find.text('50'), findsNothing);
    });
  });

  group('DeliveryInfo', () {
    testWidgets('displays estimated minutes', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const DeliveryInfo(estimatedMinutes: 30),
      ));

      expect(find.text('30 min'), findsOneWidget);
    });

    testWidgets('displays delivery fee', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const DeliveryInfo(deliveryFee: 15.0),
      ));

      expect(find.text('15 ج.م'), findsOneWidget);
    });

    testWidgets('displays free delivery when fee is 0', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const DeliveryInfo(deliveryFee: 0),
      ));

      expect(find.text('Free Delivery'), findsOneWidget);
    });

    testWidgets('displays minimum order', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const DeliveryInfo(minimumOrder: 25.0),
      ));

      expect(find.text('Min 25 ج.م'), findsOneWidget);
    });

    testWidgets('displays all info when all provided', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const DeliveryInfo(
          estimatedMinutes: 30,
          deliveryFee: 10.0,
          minimumOrder: 25.0,
        ),
      ));

      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('10 ج.م'), findsOneWidget);
      expect(find.text('Min 25 ج.م'), findsOneWidget);
    });

    testWidgets('hides sections when null', (tester) async {
      await tester.pumpWidget(wrapInApp(const DeliveryInfo()));

      expect(find.byIcon(Icons.access_time), findsNothing);
      expect(find.byIcon(Icons.delivery_dining), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    });
  });

  group('MerchantTypeChip', () {
    testWidgets('displays correct label for restaurant', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.restaurant),
      ));

      expect(find.text('Restaurant'), findsOneWidget);
    });

    testWidgets('displays correct label for grocery', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.grocery),
      ));

      expect(find.text('Grocery'), findsOneWidget);
    });

    testWidgets('displays correct label for pharmacy', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.pharmacy),
      ));

      expect(find.text('Pharmacy'), findsOneWidget);
    });

    testWidgets('displays correct label for electronics', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.electronics),
      ));

      expect(find.text('Electronics'), findsOneWidget);
    });

    testWidgets('displays correct label for home', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.home),
      ));

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('renders ActionChip', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.restaurant),
      ));

      expect(find.byType(ActionChip), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapInApp(
        MerchantTypeChip(
          type: MerchantType.restaurant,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(ActionChip));
      expect(tapped, isTrue);
    });

    testWidgets('works without onTap', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const MerchantTypeChip(type: MerchantType.restaurant),
      ));

      expect(find.byType(ActionChip), findsOneWidget);
    });
  });
}
