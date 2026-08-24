import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/delivery/data/datasources/remote/supabase_delivery_data_source.dart';
import 'package:delwaqty/features/customer/delivery/data/repositories/delivery_repository_impl.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/driver_capability.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/merchant_profile.dart';
import 'package:delwaqty/features/customer/delivery/domain/repositories/delivery_repository.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/ride_offer.dart';

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

final deliveryOrderByIdProvider =
    FutureProvider.family<DeliveryOrder?, String>((ref, id) {
  return ref.watch(deliveryRepositoryProvider).getDeliveryOrderById(id);
});

final driverCapabilitiesProvider =
    FutureProvider.family<DriverCapability, String>((ref, driverId) {
  return ref.watch(deliveryRepositoryProvider).getDriverCapabilities(driverId);
});

final merchantProfileProvider =
    FutureProvider.family<MerchantProfile?, String>((ref, merchantId) {
  return ref.watch(deliveryRepositoryProvider).getMerchantProfile(merchantId);
});


