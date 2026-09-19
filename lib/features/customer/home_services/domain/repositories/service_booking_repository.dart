import '../entities/service_category.dart';
import '../entities/service_provider.dart';
import '../entities/service_booking.dart';
import '../entities/car_product.dart';

abstract class ServiceBookingRepository {
  Future<List<ServiceCategory>> getCategories();
  Future<List<ServiceProvider>> getProviders({
    ServiceCategoryType? categoryType,
    String? city,
  });
  Future<ServiceProvider?> getProvider(String id);
  Future<List<ServiceBooking>> getUserBookings({String? userId});
  Future<ServiceBooking?> getBooking(String id);
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
  });
  Future<ServiceBooking> updateBookingStatus(String id, BookingStatus status);
  Future<void> cancelBooking(String id);
  Future<String> submitDeliveryCarRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required String phone,
    double? pickupLat,
    double? pickupLng,
    String? note,
  });
  Future<List<Map<String, dynamic>>> getMyDeliveryCarRequests();

  Future<List<CarProduct>> getAvailableCarProducts({
    String? city,
    String? category,
  });
  Future<CarProduct?> getCarProduct(String id);
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
  });
  Future<String> submitCarTripOrder({
    required String carProductId,
    required String pickupAddress,
    required String dropoffAddress,
    required String phone,
    double? pickupLat,
    double? pickupLng,
    DateTime? scheduledAt,
    String? note,
  });
}
