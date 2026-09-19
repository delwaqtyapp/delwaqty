import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_booking.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/car_product.dart';
import 'package:delwaqty/features/customer/home_services/domain/repositories/service_booking_repository.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/data/datasources/local/hive_cache_service.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';

final cachedServiceBookingRepositoryProvider =
    Provider<CachedServiceBookingRepository>((ref) {
      return CachedServiceBookingRepository(
        inner: ref.watch(serviceBookingRepositoryProvider),
        cache: ref.watch(hiveCacheServiceProvider),
        connectivity: ref.watch(connectivityServiceProvider),
      );
    });

class CachedServiceBookingRepository implements ServiceBookingRepository {
  CachedServiceBookingRepository({
    required this.inner,
    required this.cache,
    required this.connectivity,
  });

  final ServiceBookingRepository inner;
  final HiveCacheService cache;
  final ConnectivityService connectivity;

  bool get _isOnline =>
      connectivity.currentStatus == ConnectivityStatus.connected;

  @override
  Future<List<ServiceCategory>> getCategories() async {
    if (_isOnline) {
      try {
        final fresh = await inner.getCategories();
        await cache.cacheServiceCategories(fresh);
        return fresh;
      } catch (_) {
        final cached = cache.getCachedServiceCategories();
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    }
    final cached = cache.getCachedServiceCategories();
    if (cached.isNotEmpty) return cached;
    return inner.getCategories();
  }

  @override
  Future<List<CarProduct>> getAvailableCarProducts({
    String? city,
    String? category,
  }) {
    return inner.getAvailableCarProducts(city: city, category: category);
  }

  @override
  Future<CarProduct?> getCarProduct(String id) {
    return inner.getCarProduct(id);
  }

  @override
  Future<String> createCarProduct({
    required String sellerId,
    required String category,
    required String make,
    required String model,
    int? year,
    String? color,
    int? seats,
    String? photoUrl,
    required String city,
    required double price,
    String? description,
    double? lat,
    double? lng,
  }) {
    return inner.createCarProduct(
      sellerId: sellerId,
      category: category,
      make: make,
      model: model,
      year: year,
      color: color,
      seats: seats,
      photoUrl: photoUrl,
      city: city,
      price: price,
      description: description,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Future<String> submitCarTripOrder({
    required String carProductId,
    required String pickupAddress,
    required String dropoffAddress,
    required String phone,
    double? pickupLat,
    double? pickupLng,
    DateTime? scheduledAt,
    String? note,
  }) {
    return inner.submitCarTripOrder(
      carProductId: carProductId,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      phone: phone,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      scheduledAt: scheduledAt,
      note: note,
    );
  }

  @override
  Future<List<ServiceProvider>> getProviders({
    ServiceCategoryType? categoryType,
    String? city,
  }) async {
    return inner.getProviders(categoryType: categoryType, city: city);
  }

  @override
  Future<ServiceProvider?> getProvider(String id) {
    return inner.getProvider(id);
  }

  @override
  Future<List<ServiceBooking>> getUserBookings({String? userId}) {
    return inner.getUserBookings(userId: userId);
  }

  @override
  Future<ServiceBooking?> getBooking(String id) {
    return inner.getBooking(id);
  }

  @override
  Future<ServiceBooking> createBooking({
    required String userId,
    required String providerId,
    required String providerName,
    required ServiceCategoryType categoryType,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTime,
    required String address,
    double? addressLatitude,
    double? addressLongitude,
    double? estimatedPrice,
    String? notes,
  }) {
    return inner.createBooking(
      userId: userId,
      providerId: providerId,
      providerName: providerName,
      categoryType: categoryType,
      description: description,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      address: address,
      addressLatitude: addressLatitude,
      addressLongitude: addressLongitude,
      estimatedPrice: estimatedPrice,
      notes: notes,
    );
  }

  @override
  Future<ServiceBooking> updateBookingStatus(String id, BookingStatus status) {
    return inner.updateBookingStatus(id, status);
  }

  @override
  Future<void> cancelBooking(String id) {
    return inner.cancelBooking(id);
  }

  @override
  Future<String> submitDeliveryCarRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required String phone,
    double? pickupLat,
    double? pickupLng,
    String? note,
  }) {
    return inner.submitDeliveryCarRequest(
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      phone: phone,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      note: note,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMyDeliveryCarRequests() {
    return inner.getMyDeliveryCarRequests();
  }
}
