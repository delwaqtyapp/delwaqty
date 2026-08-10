import '../entities/service_category.dart';
import '../entities/service_provider.dart';
import '../entities/service_booking.dart';

abstract class ServiceBookingRepository {
  Future<List<ServiceCategory>> getCategories();
  Future<List<ServiceProvider>> getProviders({ServiceCategoryType? categoryType, String? city});
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
}
