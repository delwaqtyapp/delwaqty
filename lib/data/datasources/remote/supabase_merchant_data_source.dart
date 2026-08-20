import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';

final supabaseMerchantDataSourceProvider = Provider<SupabaseMerchantDataSource>(
  (ref) {
    return SupabaseMerchantDataSource(
      ref.watch(supabaseClientProvider),
      ref.watch(loggerProvider),
    );
  },
);

class SupabaseMerchantDataSource {
  SupabaseMerchantDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _tableName = 'merchants';

  Map<String, dynamic> _rowToMap(dynamic row) => row as Map<String, dynamic>;

  Merchant _fromRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String? ?? 'other';
    final type = MerchantType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => MerchantType.other,
    );
    return Merchant(
      id: row['id'] as String,
      name: row['name'] as String,
      type: type,
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
      address: row['address'] as String?,
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (row['total_reviews'] as int?) ?? (row['total_orders'] as int?) ?? 0,
      imageUrl: row['logo_url'] as String?,
      description: row['description'] as String?,
      isVerified: (row['status'] as String?) == 'active',
      isFeatured: (row['is_featured'] as bool?) ?? false,
      deliveryAvailable: true,
      pickupAvailable: true,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  Future<List<Merchant>> getMerchants({
    MerchantType? type,
    String? city,
    bool? isOpenNow,
    SearchFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _client.from(_tableName).select().eq('status', 'active');

      if (type != null) {
        query = query.eq('type', type.name);
      }

      if (filter?.minRating != null) {
        query = query.gte('rating', filter!.minRating!);
      }

      final data = await query
          .order('is_featured', ascending: false)
          .order('rating', ascending: false)
          .range(offset, offset + limit - 1);

      return (data as List).map((row) => _fromRow(_rowToMap(row))).toList();
    } catch (e, stack) {
      _logger.e('Failed to get merchants', e, stack);
      rethrow;
    }
  }

  Future<Merchant?> getMerchantById(String id) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return _fromRow(_rowToMap(data));
    } catch (e, stack) {
      _logger.e('Failed to get merchant: $id', e, stack);
      rethrow;
    }
  }

  Future<List<Merchant>> getFeaturedMerchants() async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('status', 'active')
          .eq('is_featured', true)
          .order('rating', ascending: false)
          .limit(10);
      return (data as List).map((row) => _fromRow(_rowToMap(row))).toList();
    } catch (e, stack) {
      _logger.e('Failed to get featured merchants', e, stack);
      rethrow;
    }
  }

  Future<List<Merchant>> searchMerchants(String query) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('rating', ascending: false)
          .limit(20);
      return (data as List).map((row) => _fromRow(_rowToMap(row))).toList();
    } catch (e, stack) {
      _logger.e('Failed to search merchants: $query', e, stack);
      rethrow;
    }
  }

  Future<List<Merchant>> getMerchantsByType(MerchantType type) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('type', type.name)
          .order('rating', ascending: false);
      return (data as List).map((row) => _fromRow(_rowToMap(row))).toList();
    } catch (e, stack) {
      _logger.e('Failed to get merchants by type: ${type.name}', e, stack);
      rethrow;
    }
  }
}
