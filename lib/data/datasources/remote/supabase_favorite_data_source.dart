import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';

final supabaseFavoriteDataSourceProvider =
    Provider<SupabaseFavoriteDataSource>((ref) {
  return SupabaseFavoriteDataSource(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

class SupabaseFavoriteDataSource {
  SupabaseFavoriteDataSource(this._client, this._logger);

  final SupabaseClient _client;
  final AppLogger _logger;

  static const String _tableName = 'favorites';

  String? get _userId => _client.auth.currentUser?.id;

  Favorite _fromRow(Map<String, dynamic> row) {
    return Favorite(
      id: row['id'] as String,
      targetId: row['product_id'] as String? ?? row['merchant_id'] as String,
      type: row['product_id'] != null
          ? FavoriteType.product
          : FavoriteType.merchant,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<List<Favorite>> getFavorites({FavoriteType? type}) async {
    try {
      final userId = _userId;
      if (userId == null) return [];

      var query = _client
          .from(_tableName)
          .select()
          .eq('user_id', userId);

      if (type == FavoriteType.product) {
        query = query.not('product_id', 'is', null);
      } else if (type == FavoriteType.merchant) {
        query = query.not('merchant_id', 'is', null);
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _logger.e('Failed to get favorites', e, stack);
      rethrow;
    }
  }

  Future<bool> isFavorite(String targetId, FavoriteType type) async {
    try {
      final userId = _userId;
      if (userId == null) return false;

      final column = type == FavoriteType.product ? 'product_id' : 'merchant_id';
      final data = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq(column, targetId)
          .maybeSingle();
      return data != null;
    } catch (e, stack) {
      _logger.e('Failed to check favorite status', e, stack);
      rethrow;
    }
  }

  Future<void> toggleFavorite({
    required String targetId,
    required FavoriteType type,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('User not authenticated');

      final column = type == FavoriteType.product ? 'product_id' : 'merchant_id';
      final existing = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .eq(column, targetId)
          .maybeSingle();

      if (existing != null) {
        await _client.from(_tableName).delete().eq('id', existing['id']);
        _logger.i('Removed favorite: $targetId');
      } else {
        await _client.from(_tableName).insert({
          'user_id': userId,
          column: targetId,
        });
        _logger.i('Added favorite: $targetId');
      }
    } catch (e, stack) {
      _logger.e('Failed to toggle favorite', e, stack);
      rethrow;
    }
  }
}
