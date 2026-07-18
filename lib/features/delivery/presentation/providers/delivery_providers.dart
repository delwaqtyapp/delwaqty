import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/delivery/data/datasources/remote/supabase_delivery_data_source.dart';
import 'package:delwaqty/features/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:delwaqty/features/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:delwaqty/features/driver/domain/entities/ride_offer.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepositoryImpl(ref.watch(supabaseDeliveryDataSourceProvider));
});

final deliveryOffersProvider =
    StreamProvider.family<List<RideOffer>, String>((ref, driverId) {
  return ref.watch(deliveryRepositoryProvider).watchDeliveryOffers(driverId);
});

final activeDeliveryProvider =
    StreamProvider.family<DeliveryOrder?, String>((ref, driverId) {
  return ref.watch(deliveryRepositoryProvider).watchActiveDelivery(driverId);
});

final driverCapabilitiesProvider =
    FutureProvider.family<DriverCapability, String>((ref, driverId) {
  return ref.watch(deliveryRepositoryProvider).getDriverCapabilities(driverId);
});

final merchantProfileProvider =
    FutureProvider.family<MerchantProfile?, String>((ref, merchantId) {
  return ref.watch(deliveryRepositoryProvider).getMerchantProfile(merchantId);
});

final merchantDeliveriesProvider =
    FutureProvider.family<List<DeliveryOrder>, ({String merchantId, String? status})>((ref, params) {
  return ref.watch(deliveryRepositoryProvider).getMerchantDeliveries(params.merchantId, status: params.status);
});
