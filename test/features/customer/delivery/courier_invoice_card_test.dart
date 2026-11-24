import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/repositories/delivery_repository.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/delivery/presentation/widgets/courier_invoice_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeDeliveryRepository extends Fake implements DeliveryRepository {
  final List<(String, String)> decisions = [];

  @override
  Future<void> decideCourierInvoiceItem(String itemId, String action) async {
    decisions.add((itemId, action));
  }
}

const _state = AskAnythingRideState(
  rideId: 'r1',
  status: 'matched',
  shopCount: 2,
  quoteLocked: true,
  goodsTotal: 0,
  shoppingFinished: false,
  fare: 20,
);

Widget _app(
  List<CourierInvoiceItem> items,
  _FakeDeliveryRepository repo, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      courierInvoiceItemsProvider('r1')
          .overrideWith((ref) => Stream.value(items)),
      deliveryRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const Scaffold(
        body: SingleChildScrollView(child: CourierInvoiceCard(state: _state)),
      ),
    ),
  );
}

CourierInvoiceItem _item({
  String id = 'i1',
  String status = 'pending',
  double? quantity,
  String? unit,
  String? receiptPhotoUrl,
  double price = 37.5,
}) => CourierInvoiceItem(
  id: id,
  rideId: 'r1',
  shopName: 'Al Gomhoreya',
  productName: 'Paracetamol 500',
  unit: unit,
  quantity: quantity,
  price: price,
  receiptPhotoUrl: receiptPhotoUrl,
  status: status,
);

void main() {
  testWidgets('shows quantity with a localized unit and the receipt link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _item(quantity: 2, unit: 'kilo', receiptPhotoUrl: 'https://x/r.jpg'),
      ], _FakeDeliveryRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ×'), findsOneWidget);
    expect(find.text('View receipt'), findsOneWidget);
    // A pending item keeps the total provisional, never the final bill.
    expect(find.textContaining('Provisional'), findsOneWidget);
  });

  testWidgets('approving a pending item calls the repository once', (
    tester,
  ) async {
    final repo = _FakeDeliveryRepository();
    await tester.pumpWidget(_app([_item(quantity: 1, unit: 'piece')], repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(repo.decisions, [('i1', 'approve')]);
  });

  testWidgets('a failed items stream shows an error with a retry, no totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courierInvoiceItemsProvider('r1')
              .overrideWith((ref) => Stream.error(StateError('boom'))),
          deliveryRepositoryProvider.overrideWithValue(
            _FakeDeliveryRepository(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CourierInvoiceCard(state: _state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Provisional'), findsNothing);
  });

  testWidgets('Arabic renders the localized unit', (tester) async {
    await tester.pumpWidget(
      _app(
        [_item(quantity: 2, unit: 'half')],
        _FakeDeliveryRepository(),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('نص كيلو'), findsOneWidget);
  });
}
