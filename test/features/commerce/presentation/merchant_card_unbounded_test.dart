import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Regression: the /market featured carousel hosts MerchantCard inside a
/// horizontal ListView whose cross axis (height) is UNBOUNDED, exactly like
/// this SingleChildScrollView. A `Flexible` inside the card's Column would
/// throw "RenderFlex children have non-zero flex but incoming height
/// constraints are unbounded" and (in a plain debug APK) kill the app with a
/// white screen. The card must build cleanly in this context.
Widget wrapUnboundedHeight(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 260,
            child: child,
          ),
        ),
      ),
    );

Merchant buildMerchant() => Merchant(
      id: 'm-unbounded',
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
      'MerchantCard builds inside unbounded-height host (featured carousel) without throwing',
      (tester) async {
    await tester.pumpWidget(
      wrapUnboundedHeight(
        MerchantCard(merchant: buildMerchant(), onTap: () {}),
      ),
    );
    await tester.pump();
    expect(find.byType(MerchantCard), findsOneWidget);
    expect(find.text('مطعم البيك'), findsOneWidget);
  });

  testWidgets('MerchantCard builds inside a bounded grid cell without overflow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 0.74,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              MerchantCard(merchant: buildMerchant(), onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MerchantCard), findsOneWidget);
  });
}