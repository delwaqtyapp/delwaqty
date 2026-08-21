import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_booking.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/repositories/service_booking_repository.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/data/datasources/local/hive_cache_service.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';

final cachedServiceBookingRepositoryProvider = Provider<CachedServiceBookingRepository>((ref) {
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

  bool get _isOnline => connectivity.currentStatus == ConnectivityStatus.connected;

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
}
