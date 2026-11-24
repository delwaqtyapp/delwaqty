import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:delwaqty/features/customer/delivery/data/datasources/remote/supabase_delivery_data_source.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_shopping_item.dart';

void main() {
  group('AskAnythingRideState', () {
    test('quoteBaseline is 15 + 5 per extra shop (owner model, #211)', () {
      AskAnythingRideState build(int shops) => AskAnythingRideState(
        rideId: 'r',
        status: 'searching',
        shopCount: shops,
        quoteLocked: false,
        goodsTotal: 0,
        shoppingFinished: false,
      );
      expect(build(1).quoteBaseline, 15);
      expect(build(2).quoteBaseline, 20);
      expect(build(3).quoteBaseline, 25);
      expect(build(10).quoteBaseline, 60);
    });

    test('fromRow reads the migrated columns with safe defaults', () {
      final state = AskAnythingRideState.fromRow(const {
        'id': 'ride-1',
        'courier_shop_count': 3,
        'courier_quote_locked': true,
        'fare': 25.0,
        'courier_shopping_finished': false,
        'courier_goods_total': 40.5,
      });
      expect(state.rideId, 'ride-1');
      expect(state.shopCount, 3);
      expect(state.quoteLocked, isTrue);
      expect(state.fare, 25.0);
      expect(state.quoteBaseline, 25);
      expect(state.shoppingFinished, isFalse);
      expect(state.goodsTotal, 40.5);
    });

    test('fromRow defaults when the migration columns are absent', () {
      final state = AskAnythingRideState.fromRow(const {'id': 'ride-2'});
      expect(state.shopCount, 1);
      expect(state.quoteLocked, isFalse);
      expect(state.fare, isNull);
      expect(state.goodsTotal, 0);
      expect(state.shoppingFinished, isFalse);
    });
  });

  group('CourierQuote', () {
    test('fromRow maps roles and statuses', () {
      final quote = CourierQuote.fromRow(const {
        'id': 'q1',
        'ride_id': 'r1',
        'proposed_by_role': 'driver',
        'amount': 30,
        'note': 'with waiting',
        'status': 'pending',
      });
      expect(quote.isFromDriver, isTrue);
      expect(quote.isPending, isTrue);
      expect(quote.amount, 30);
      expect(quote.note, 'with waiting');

      final counter = CourierQuote.fromRow(const {
        'id': 'q2',
        'ride_id': 'r1',
        'proposed_by_role': 'customer',
        'amount': 20,
        'status': 'accepted',
      });
      expect(counter.isFromDriver, isFalse);
      expect(counter.isPending, isFalse);
    });
  });

  group('CourierInvoiceItem', () {
    test('fromRow maps status helpers', () {
      final pending = CourierInvoiceItem.fromRow(const {
        'id': 'i1',
        'ride_id': 'r1',
        'status': 'pending',
        'shop_name': 'Al Gomhoreya',
        'product_name': 'Paracetamol 500',
        'price': 12.5,
      });
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
      expect(pending.isCancelled, isFalse);

      final approved = CourierInvoiceItem.fromRow(const {
        'id': 'i2',
        'ride_id': 'r1',
        'status': 'approved',
        'price': 7.25,
      });
      expect(approved.isApproved, isTrue);
      expect(approved.price, 7.25);

      final cancelled = CourierInvoiceItem.fromRow(const {
        'id': 'i3',
        'ride_id': 'r1',
        'status': 'cancelled',
        'price': 3,
      });
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isRejected, isFalse);
    });
  });

  group('CourierShoppingItem', () {
    test('toJson omits amount unless the unit is an EGP amount', () {
      const item = CourierShoppingItem(productName: 'Rice 5kg', unit: 'kilo');
      expect(item.toJson(), {'product_name': 'Rice 5kg', 'unit': 'kilo'});

      const amountItem = CourierShoppingItem(
        productName: 'Butcher cut',
        unit: 'amount',
        amountEgp: 100,
      );
      expect(amountItem.toJson(), {
        'product_name': 'Butcher cut',
        'unit': 'amount',
        'amount_egp': 100,
      });
    });
  });

  group('436 RPC contract', () {
    test('checkedRpcResult throws the server reason on ok:false', () {
      expect(
        () => checkedRpcResult({
          'ok': false,
          'reason': 'BELOW_BASELINE',
        }, onFailure: DeliveryException.new),
        throwsA(
          isA<DeliveryException>().having(
            (e) => e.reason,
            'reason',
            'BELOW_BASELINE',
          ),
        ),
      );
      expect(checkedRpcResult({'ok': true}, onFailure: DeliveryException.new), {
        'ok': true,
      });
    });

    test(
      'courierErrorMessage maps every 436 reason to a specific text',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final codes = {
          'BELOW_BASELINE': l10n.courierErrBelowBaseline,
          'QUOTE_CAP': l10n.courierErrQuoteCap,
          'GOODS_CAP': l10n.courierErrGoodsCap,
          'SHOP_CAP': l10n.courierErrShopCap,
          'ITEM_CAP': l10n.courierItemsLimit,
          'THROTTLED': l10n.courierErrThrottled,
          'INVALID_AMOUNT': l10n.courierErrInvalidAmount,
          'INVALID_ITEMS': l10n.courierErrInvalidItems,
          'INVALID_INPUT': l10n.courierErrInvalidInput,
          'INVALID_STATE': l10n.courierErrInvalidState,
          'ITEMS_PENDING': l10n.courierErrItemsPending,
          'ITEM_NOT_PENDING': l10n.courierErrItemNotPending,
          'NO_QUOTE_TO_COUNTER': l10n.courierErrNoQuoteToCounter,
          'QUOTE_ALREADY_LOCKED': l10n.courierErrQuoteAlreadyLocked,
          'QUOTE_NOT_LOCKED': l10n.courierErrQuoteNotLocked,
          'QUOTE_NOT_PENDING': l10n.courierErrQuoteNotPending,
          'REJECTED_ITEMS_OPEN': l10n.courierErrRejectedItemsOpen,
          'DRIVER_CHANGED': l10n.courierErrPartyChanged,
          'RIDER_CHANGED': l10n.courierErrPartyChanged,
          'TOO_MANY_OPEN_RIDES': l10n.courierErrTooManyOpenRides,
          'ask_anything_cash_only': l10n.courierErrCashOnly,
          'ask_anything_goods_in_progress': l10n.courierErrGoodsInProgress,
        };
        for (final entry in codes.entries) {
          expect(
            courierErrorMessage(l10n, DeliveryException(entry.key)),
            entry.value,
            reason: entry.key,
          );
        }
      },
    );

    test(
      'invoice item parses quantity, unit and receipt for display (#214)',
      () {
        final item = CourierInvoiceItem.fromRow(const {
          'id': 'i9',
          'ride_id': 'r1',
          'shop_name': 'Seif',
          'product_name': 'Rice',
          'unit': 'kilo',
          'quantity': 2,
          'price': 90,
          'receipt_photo_url': 'https://example/r.jpg',
          'status': 'pending',
        });
        expect(item.quantity, 2);
        expect(item.unit, 'kilo');
        expect(item.receiptPhotoUrl, 'https://example/r.jpg');
      },
    );
  });
}
