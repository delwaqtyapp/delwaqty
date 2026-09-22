import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Regression suite for the /market layout bugs:
/// 1. The featured carousel hosts MerchantCard inside a horizontal ListView.
///    That ListView MUST be wrapped in a bounded-height SizedBox — without it
///    Flutter throws "Horizontal viewport was given unbounded height", which
///    in a plain debug APK leaves a WHITE VOID between the filter buttons and
///    «الأكثر طلبا» (and previously killed the app). The card itself uses a
///    Flexible text block which is only legal inside a bounded host.
/// 2. The grid cell (childAspectRatio 0.74) must never overflow regardless of
///    font scale — the Flexible + ellipsis combo guarantees it.
Widget wrapInApp(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

Merchant buildMerchant() => Merchant(
      id: 'm-reg',
      name: 'مطعم البيك',
      type: MerchantType.restaurant,
      latitude: 30.0444,
      longitude: 31.2357,
      rating: 4.8,
      isOpenNow: true,
      isVerified: true,
      deliveryAvailable: true,
      estimatedDeliveryMinutes: 30,
      deliveryFee: 10.0,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/ar/thumb/d/d8/Al-Baik_Logo.svg/800px-Al-Baik_Logo.svg.png',
      createdAt: DateTime(2025),
    );

void main() {
  testWidgets(
      'featured carousel (horizontal ListView in SizedBox 250) renders cards without the unbounded-height throw',
      (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('المميزة'),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 2,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 260,
                    child: MerchantCard(
                      merchant: buildMerchant(),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MerchantCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'raw horizontal ListView WITHOUT a bounded height must throw (documents the white-void bug)',
      (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        SingleChildScrollView(
          child: Column(
            children: [
              ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    const SizedBox(width: 260, child: ColoredBox(color: Colors.amber)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('MerchantCard inside a 0.74 grid cell renders without overflow',
      (tester) async {
    await tester.pumpWidget(
      wrapInApp(
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.74,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            MerchantCard(merchant: buildMerchant(), onTap: () {}),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MerchantCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}