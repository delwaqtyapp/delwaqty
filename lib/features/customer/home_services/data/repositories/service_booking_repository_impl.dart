import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_provider.dart';
import '../../domain/entities/service_booking.dart';
import '../../domain/repositories/service_booking_repository.dart';

class ServiceBookingRepositoryImpl implements ServiceBookingRepository {
  final SupabaseClient _client;

  ServiceBookingRepositoryImpl(this._client);

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
}

final serviceBookingRepositoryProvider =
    Provider<ServiceBookingRepository>((ref) {
  return ServiceBookingRepositoryImpl(Supabase.instance.client);
});
