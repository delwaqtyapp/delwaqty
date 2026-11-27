import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';

Favorite _fav(String id, FavoriteType t) =>
    Favorite(id: 'f-$id', targetId: id, type: t, createdAt: DateTime(2026));

void main() {
  test(
    'keeps favorite shops in order, skips products and missing shops',
    () async {
      final loaded = <String>[];
      final result = await favoriteMerchantEntries(
        favorites: [
          _fav('m1', FavoriteType.merchant),
          _fav('p1', FavoriteType.product),
          _fav('gone', FavoriteType.merchant),
          _fav('m2', FavoriteType.merchant),
          _fav('m1', FavoriteType.merchant),
        ],
        loadMerchant: (id) async {
          loaded.add(id);
          if (id == 'gone') return null;
          if (id == 'boom') throw Exception('x');
          return Merchant(
            id: id,
            name: id,
            type: MerchantType.restaurant,
            latitude: 0,
            longitude: 0,
            createdAt: DateTime(2026),
          );
        },
      );
      expect(loaded, ['m1', 'gone', 'm2']);
      expect(result.map((e) => (e as MerchantDiscoveryEntry).merchant.id), [
        'm1',
        'm2',
      ]);
    },
  );

  test('a failing lookup is skipped, not fatal', () async {
    final result = await favoriteMerchantEntries(
      favorites: [_fav('boom', FavoriteType.merchant)],
      loadMerchant: (id) => Future.error(Exception('x')),
    );
    expect(result, isEmpty);
  });
}
