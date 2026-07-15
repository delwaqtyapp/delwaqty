import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/domain/repositories/favorite_repository.dart';

class MockFavoriteRepository implements FavoriteRepository {
  final List<Favorite> _favorites = [];

  @override
  Future<List<Favorite>> getFavorites({FavoriteType? type}) async {
    if (type != null) {
      return _favorites.where((f) => f.type == type).toList();
    }
    return List.unmodifiable(_favorites);
  }

  @override
  Future<bool> isFavorite(String targetId, FavoriteType type) async =>
      _favorites.any((f) => f.targetId == targetId && f.type == type);

  @override
  Future<void> toggleFavorite({
    required String targetId,
    required FavoriteType type,
  }) async {
    final existing = _favorites.indexWhere(
      (f) => f.targetId == targetId && f.type == type,
    );
    if (existing >= 0) {
      _favorites.removeAt(existing);
    } else {
      _favorites.add(Favorite(
        id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
        targetId: targetId,
        type: type,
        createdAt: DateTime.now(),
      ));
    }
  }
}
