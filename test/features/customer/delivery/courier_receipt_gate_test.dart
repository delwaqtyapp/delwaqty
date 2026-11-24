import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/presentation/widgets/courier_receipt_card.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/delivery/presentation/widgets/courier_receipt_gate.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

const _state = AskAnythingRideState(
  rideId: 'r1',
  status: 'completed',
  shopCount: 2,
  quoteLocked: true,
  goodsTotal: 40,
  shoppingFinished: true,
  fare: 20,
);

Widget _app(
  AsyncValue<AskAnythingRideState?> askAsync, {
  bool terminal = true,
}) {
  return ProviderScope(
    overrides: [
      courierInvoiceItemsProvider('r1')
          .overrideWith((ref) => Stream.value(const [])),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CourierReceiptGate(
          askAsync: askAsync,
          isTerminal: terminal,
          onRetry: () {},
          fallback: const Text('GENERIC RECEIPT'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a failed outer stream shows retry and NEVER the generic money receipt',
    (tester) async {
      await tester.pumpWidget(
        _app(AsyncValue.error(StateError('boom'), StackTrace.empty)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('GENERIC RECEIPT'), findsNothing);
      expect(find.byType(CourierReceiptCard), findsNothing);
    },
  );

  testWidgets('loading shows no receipt at all', (tester) async {
    await tester.pumpWidget(_app(const AsyncValue.loading()));
    await tester.pump();

    expect(find.text('GENERIC RECEIPT'), findsNothing);
    expect(find.byType(CourierReceiptCard), findsNothing);
  });

  testWidgets('data(null) proves a plain ride: the generic receipt renders', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AsyncValue.data(null)));
    await tester.pumpAndSettle();

    expect(find.text('GENERIC RECEIPT'), findsOneWidget);
  });

  testWidgets('data(state) on a terminal ride shows the courier receipt', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AsyncValue.data(_state)));
    await tester.pumpAndSettle();

    expect(find.byType(CourierReceiptCard), findsOneWidget);
    expect(find.text('GENERIC RECEIPT'), findsNothing);
  });

  testWidgets('data(state) during the ride renders nothing here', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AsyncValue.data(_state), terminal: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('GENERIC RECEIPT'), findsNothing);
    expect(find.byType(CourierReceiptCard), findsNothing);
  });
}
