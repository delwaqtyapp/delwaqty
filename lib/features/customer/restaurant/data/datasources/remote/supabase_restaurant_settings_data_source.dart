import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/restaurant_settings.dart';

final supabaseRestaurantSettingsDataSourceProvider =
    Provider<SupabaseRestaurantSettingsDataSource>((ref) {
      return SupabaseRestaurantSettingsDataSource(
        ref.watch(supabaseClientProvider),
      );
    });

class SupabaseRestaurantSettingsDataSource {
  SupabaseRestaurantSettingsDataSource(this._client);
  final SupabaseClient _client;

  RestaurantSettings _fromRow(Map<String, dynamic> row) => RestaurantSettings(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    acceptsReservations: row['accepts_reservations'] as bool? ?? false,
    hasDineIn: row['has_dine_in'] as bool? ?? true,
    hasTakeaway: row['has_takeaway'] as bool? ?? true,
    hasDelivery: row['has_delivery'] as bool? ?? true,
    averagePrepTime: row['average_prep_time'] as int? ?? 15,
    maxOrdersPerHour: row['max_orders_per_hour'] as int? ?? 20,
    autoAcceptOrders: row['auto_accept_orders'] as bool? ?? false,
    printerEnabled: row['printer_enabled'] as bool? ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : null,
  );

  Future<RestaurantSettings?> getSettings(String merchantId) async {
    final data = await _client
        .from('restaurant_settings')
        .select()
        .eq('merchant_id', merchantId)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }
}
