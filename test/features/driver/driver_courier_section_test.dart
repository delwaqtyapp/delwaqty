import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_shopping_item.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/driver/domain/repositories/driver_repository.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/presentation/widgets/driver_courier_section.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeDriverRepository extends Fake implements DriverRepository {
  Completer<void>? cancelGate;
  final List<String> cancelled = [];

  @override
  Future<void> cancelCourierInvoiceItem(String itemId) async {
    cancelled.add(itemId);
    await cancelGate?.future;
  }
}

const _negotiating = AskAnythingRideState(
  rideId: 'r1',
  status: 'matched',
  shopCount: 3,
  quoteLocked: false,
  goodsTotal: 0,
  shoppingFinished: false,
);

const _shoppingDone = AskAnythingRideState(
  rideId: 'r1',
  status: 'matched',
  shopCount: 1,
  quoteLocked: true,
  goodsTotal: 55.50,
  shoppingFinished: true,
  fare: 45,
);

Widget _app(
  AskAnythingRideState state,
  _FakeDriverRepository repo, {
  List<CourierShoppingItem> requestItems = const [],
  List<CourierInvoiceItem> invoiceItems = const [],
}) {
  return ProviderScope(
    overrides: [
      askAnythingRideProvider(state.rideId)
          .overrideWith((ref) => Stream.value(state)),
      driverCourierRequestItemsProvider(state.rideId)
          .overrideWith((ref) => Stream.value(requestItems)),
      courierQuotesProvider(state.rideId)
          .overrideWith((ref) => Stream.value(const [])),
      courierInvoiceItemsProvider(state.rideId)
          .overrideWith((ref) => Stream.value(invoiceItems)),
      driverRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DriverCourierSection(rideId: state.rideId),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('#217: a mixed kilo/half/amount request reaches the captain', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _negotiating,
        _FakeDriverRepository(),
        requestItems: const [
          CourierShoppingItem(productName: 'Rice', unit: 'kilo'),
          CourierShoppingItem(productName: 'Sugar', unit: 'half'),
          CourierShoppingItem(
            productName: 'Butcher cut',
            unit: 'amount',
            amountEgp: 100,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Kilo'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);
    expect(find.text('Half kilo'), findsOneWidget);
    expect(find.text('Butcher cut'), findsOneWidget);
    expect(find.text('100.00 EGP'), findsOneWidget);
  });

  testWidgets(
    '#216: the finished card shows fare, goods and total with cents',
    (tester) async {
      await tester.pumpWidget(_app(_shoppingDone, _FakeDriverRepository()));
      await tester.pumpAndSettle();

      expect(find.text('45.00 EGP'), findsOneWidget);
      expect(find.text('55.50 EGP'), findsOneWidget);
      expect(find.text('100.50 EGP'), findsOneWidget);
    },
  );

  testWidgets(
    '#219: a cancelled ride shows records and the incident note, never an amount due',
    (tester) async {
      const cancelled = AskAnythingRideState(
        rideId: 'r1',
        status: 'cancelled',
        shopCount: 1,
        quoteLocked: true,
        goodsTotal: 55.50,
        shoppingFinished: true,
        fare: 45,
      );
      await tester.pumpWidget(_app(cancelled, _FakeDriverRepository()));
      await tester.pumpAndSettle();

      // Records stay visible: fare and goods lines with cents.
      expect(find.text('45.00 EGP'), findsOneWidget);
      expect(find.text('55.50 EGP'), findsOneWidget);
      // No collection instruction and no amount due: neither the total
      // nor the collect-instruction title may render.
      expect(find.text('100.50 EGP'), findsNothing);
      expect(find.textContaining('collect the delivery price'), findsNothing);
      expect(
        find.textContaining('Ride cancelled - shopping records'),
        findsOneWidget,
      );
      expect(find.textContaining('problem report'), findsWidgets);
    },
  );

  testWidgets('#218: disposing mid-RPC never throws setState-after-dispose', (
    tester,
  ) async {
    final repo = _FakeDriverRepository()..cancelGate = Completer<void>();
    final rejected = CourierInvoiceItem(
      id: 'i1',
      rideId: 'r1',
      shopName: 'Seif',
      productName: 'Bread',
      price: 10,
      status: 'rejected',
    );
    const shopping = AskAnythingRideState(
      rideId: 'r1',
      status: 'arrived',
      shopCount: 1,
      quoteLocked: true,
      goodsTotal: 0,
      shoppingFinished: false,
      fare: 20,
    );
    await tester.pumpWidget(_app(shopping, repo, invoiceItems: [rejected]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel at the shop'));
    await tester.pump(); // the RPC is now in flight behind the gate

    // Navigate away while the cancel RPC is still running.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repo.cancelGate!.complete();
    await tester.pumpAndSettle();

    expect(repo.cancelled, ['i1']);
    expect(tester.takeException(), isNull);
  });
}
