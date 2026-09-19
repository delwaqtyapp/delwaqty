import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_provider.dart';
import '../../domain/entities/service_booking.dart';
import '../../domain/entities/car_product.dart';
import '../../domain/repositories/service_booking_repository.dart';

class ServiceBookingRepositoryImpl implements ServiceBookingRepository {

  ServiceBookingRepositoryImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ServiceCategory>> getCategories() async {
    final response = await _client
        .from('service_categories')
        .select()
        .eq('is_active', true)
        .order('name_en');
    return (response as List)
        .map((json) => ServiceCategory.fromJson(json))
        .toList();
  }

  @override
  Future<List<ServiceProvider>> getProviders({
    ServiceCategoryType? categoryType,
    String? city,
  }) async {
    var query = _client.from('service_providers').select();
    if (categoryType != null) {
      query = query.eq('category_type', categoryType.name);
    }
    if (city != null) {
      query = query.eq('city', city);
    }
    final response = await query
        .eq('is_available', true)
        .order('rating', ascending: false);
    return (response as List)
        .map((json) => ServiceProvider.fromJson(json))
        .toList();
  }

  @override
  Future<ServiceProvider?> getProvider(String id) async {
    final response = await _client
        .from('service_providers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ServiceProvider.fromJson(response);
  }

  @override
  Future<List<ServiceBooking>> getUserBookings({String? userId}) async {
    var query = _client.from('service_bookings').select();
    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((json) => ServiceBooking.fromJson(json))
        .toList();
  }

  @override
  Future<ServiceBooking?> getBooking(String id) async {
    final response = await _client
        .from('service_bookings')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ServiceBooking.fromJson(response);
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
  }) async {
    final response = await _client
        .from('service_bookings')
        .insert({
          'user_id': userId,
          'provider_id': providerId,
          'provider_name': providerName,
          'category_type': categoryType.name,
          'status': 'pending',
          'description': description,
          'scheduled_date': scheduledDate.toIso8601String(),
          'scheduled_time': scheduledTime,
          'address': address,
          'address_latitude': addressLatitude,
          'address_longitude': addressLongitude,
          'estimated_price': estimatedPrice,
          'notes': notes,
        })
        .select()
        .single();
    return ServiceBooking.fromJson(response);
  }

  @override
  Future<ServiceBooking> updateBookingStatus(
      String id, BookingStatus status) async {
    final response = await _client
        .from('service_bookings')
        .update({
          'status': status.name,
          if (status == BookingStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return ServiceBooking.fromJson(response);
  }

  @override
  Future<void> cancelBooking(String id) async {
    await _client
        .from('service_bookings')
        .update({'status': 'cancelled'}).eq('id', id);
  }

  @override
  Future<String> submitDeliveryCarRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required String phone,
    double? pickupLat,
    double? pickupLng,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final res = await _client
        .from('delivery_car_requests')
        .insert({
          'user_id': uid,
          'pickup_address': pickupAddress,
          'dropoff_address': dropoffAddress,
          'phone': phone,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'note': note,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  @override
  Future<List<Map<String, dynamic>>> getMyDeliveryCarRequests() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('delivery_car_requests')
        .select()
        .eq('user_id', uid)
        .order('created_at')
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<CarProduct>> getAvailableCarProducts({
    String? city,
    String? category,
  }) async {
    var query = _client.from('car_products').select().eq('is_available', true);
    if (city != null) {
      query = query.eq('city', city);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    final response = await query.order('price');
    return (response as List)
        .map((json) => CarProduct.fromJson(json))
        .toList();
  }

  @override
  Future<CarProduct?> getCarProduct(String id) async {
    final response = await _client
        .from('car_products')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return CarProduct.fromJson(response);
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
  }) async {
    final response = await _client
        .from('car_products')
        .insert({
          'seller_id': sellerId,
          'category': category,
          'make': make,
          'model': model,
          'year': year,
          'color': color,
          'seats': seats,
          'photo_url': photoUrl,
          'city': city,
          'price': price,
          'description': description,
          'latitude': lat,
          'longitude': lng,
        })
        .select('id')
        .single();
    return response['id'] as String;
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
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    // Get the car product to get the driver's price
    final carProduct = await getCarProduct(carProductId);
    if (carProduct == null) throw Exception('Car product not found');
    final driverPrice = carProduct.price;
    // Calculate commission: 7% of driverPrice, precise to 2 decimals.
    // The total is derived from the rounded commission so the breakdown the
    // customer sees (driver price + 7% = total) always matches exactly.
    final commissionString = (driverPrice * 7 / 100).toStringAsFixed(2);
    final commissionAmount = double.parse(commissionString);
    final totalString = (driverPrice + commissionAmount).toStringAsFixed(2);
    final totalAmount = double.parse(totalString);
    // Insert into delivery_car_requests
    final response = await _client
        .from('delivery_car_requests')
        .insert({
          'user_id': uid,
          'car_product_id': carProductId,
          'driver_price': driverPrice,
          'commission_percent': 7.0,
          'commission_amount': commissionAmount,
          'total_amount': totalAmount,
          'scheduled_at': scheduledAt?.toIso8601String(),
          'pickup_address': pickupAddress,
          'dropoff_address': dropoffAddress,
          'phone': phone,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'note': note,
        })
        .select('id')
        .single();
    return response['id'] as String;
  }
}

final serviceBookingRepositoryProvider =
    Provider<ServiceBookingRepository>((ref) {
  return ServiceBookingRepositoryImpl(Supabase.instance.client);
});

final myDeliveryCarRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getMyDeliveryCarRequests();
});
