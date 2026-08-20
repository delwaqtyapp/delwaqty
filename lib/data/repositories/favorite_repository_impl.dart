import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_favorite_data_source.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/favorite_repository.dart';

class FavoriteRepositoryImpl implements FavoriteRepository {
  FavoriteRepositoryImpl(this._dataSource);

  final SupabaseFavoriteDataSource _dataSource;

  @override
  Future<List<Favorite>> getFavorites({FavoriteType? type}) async {
    try {
      return await _dataSource.getFavorites(type: type);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<bool> isFavorite(String targetId, FavoriteType type) async {
    try {
      return await _dataSource.isFavorite(targetId, type);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> toggleFavorite({
    required String targetId,
    required FavoriteType type,
  }) async {
    try {
      await _dataSource.toggleFavorite(targetId: targetId, type: type);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
