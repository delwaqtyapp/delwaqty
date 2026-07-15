import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';

abstract interface class FavoriteRepository {
  Future<List<Favorite>> getFavorites({FavoriteType? type});
  Future<bool> isFavorite(String targetId, FavoriteType type);
  Future<void> toggleFavorite({
    required String targetId,
    required FavoriteType type,
  });
}
