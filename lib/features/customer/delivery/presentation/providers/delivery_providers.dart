import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/delivery/data/datasources/remote/supabase_delivery_data_source.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/ask_anything_ride_state.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_invoice_item.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/courier_quote.dart';
import 'package:delwaqty/features/customer/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/repositories/delivery_repository.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepositoryImpl(ref.watch(supabaseDeliveryDataSourceProvider));
});

final deliveryOffersProvider = StreamProvider.family<List<RideOffer>, String>((
  ref,
  driverId,
) {
  return ref.watch(deliveryRepositoryProvider).watchDeliveryOffers(driverId);
});

final activeDeliveryProvider = StreamProvider.family<DeliveryOrder?, String>((
  ref,
  driverId,
) {
  return ref.watch(deliveryRepositoryProvider).watchActiveDelivery(driverId);
});

final deliveryOrderByIdProvider = FutureProvider.family<DeliveryOrder?, String>(
  (ref, id) {
    return ref.watch(deliveryRepositoryProvider).getDeliveryOrderById(id);
  },
);

/// Ask-anything (436) live state for the negotiation and invoice cards;
/// null while the ride is not an ask-anything courier ride.
final askAnythingRideProvider =
    StreamProvider.family<AskAnythingRideState?, String>((ref, rideId) {
      return ref.watch(deliveryRepositoryProvider).watchAskAnythingRide(rideId);
    });

final courierQuotesProvider = StreamProvider.family<List<CourierQuote>, String>(
  (ref, rideId) {
    return ref.watch(deliveryRepositoryProvider).watchCourierQuotes(rideId);
  },
);

final courierInvoiceItemsProvider =
    StreamProvider.family<List<CourierInvoiceItem>, String>((ref, rideId) {
      return ref
          .watch(deliveryRepositoryProvider)
          .watchCourierInvoiceItems(rideId);
    });

/// Cash-handoff state for the captain's "تم التحصيل" card (migration 392).
final cashCollectionStateProvider =
    FutureProvider.family<CashCollectionState?, String>((ref, rideId) {
      return ref
          .watch(deliveryRepositoryProvider)
          .getCashCollectionState(rideId);
    });

/// The delivery ride linked to a commerce order, for the customer's
/// post-collection driver rating (migration 392). A realtime stream, so the
/// rating card unlocks the moment the captain stamps the cash collection —
/// no stale "waiting for collection" state (review #71).
final orderDeliveryRideProvider =
    StreamProvider.family<OrderDeliveryRide?, String>((ref, orderId) {
      return ref
          .watch(deliveryRepositoryProvider)
          .watchOrderDeliveryRide(orderId);
    });

final driverCapabilitiesProvider =
    FutureProvider.family<DriverCapability, String>((ref, driverId) {
      return ref
          .watch(deliveryRepositoryProvider)
          .getDriverCapabilities(driverId);
    });

final merchantProfileProvider = FutureProvider.family<MerchantProfile?, String>(
  (ref, merchantId) {
    return ref.watch(deliveryRepositoryProvider).getMerchantProfile(merchantId);
  },
);
