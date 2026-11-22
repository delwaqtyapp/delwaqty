import 'dart:async';

import 'package:delwaqty/features/customer/commerce/presentation/pages/order_tracking_page.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))).load();
  });

  OrderDeliveryRide ride({DateTime? collectedAt}) => OrderDeliveryRide(
    id: 'ride-1',
    driverId: 'driver-1',
    driverName: 'كابتن',
    status: 'completed',
    paymentMethod: 'cash',
    paymentStatus: collectedAt != null ? 'paid' : 'pending',
    cashCollectedAt: collectedAt,
  );

  testWidgets(
    'customer rating card unlocks when the collection stamp streams in',
    (tester) async {
      final controller = StreamController<OrderDeliveryRide?>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderDeliveryRideProvider.overrideWith(
              (ref, orderId) => controller.stream,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(fontFamily: 'Cairo'),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DriverRatingSection(orderId: 'order-1'),
              ),
            ),
          ),
        ),
      );

      // Delivered cash order, not yet collected: waiting note, no stars.
      controller.add(ride());
      await tester.pumpAndSettle();
      expect(
        find.text('يمكنك تقييم الكابتن بعد تحصيل المبلغ.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('driverRatingCard')), findsNothing);

      // The captain taps تم التحصيل: the stamp streams in and the rating
      // card appears without any manual refresh (review #71).
      controller.add(ride(collectedAt: DateTime(2026)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('driverRatingCard')), findsOneWidget);
      expect(
        find.text('يمكنك تقييم الكابتن بعد تحصيل المبلغ.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
