import 'package:delwaqty/features/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/features/commerce/domain/repositories/catalog_category_repository.dart';

class MockCatalogCategoryRepository implements CatalogCategoryRepository {
  final Map<String, List<CatalogCategory>> _categoriesByMerchant;

  MockCatalogCategoryRepository() : _categoriesByMerchant = _sampleData();

  @override
  Future<List<CatalogCategory>> getCategories(String merchantId) async =>
      _categoriesByMerchant[merchantId] ?? [];

  @override
  Future<CatalogCategory?> getCategoryById(String id) async {
    for (final cats in _categoriesByMerchant.values) {
      try {
        return cats.firstWhere((c) => c.id == id);
      } catch (_) {}
    }
    return null;
  }
}

Map<String, List<CatalogCategory>> _sampleData() => {
  'm1': [
    CatalogCategory(
      id: 'c1',
      merchantId: 'm1',
      name: 'Meals',
      icon: 'meal',
      sortOrder: 0,
    ),
    CatalogCategory(
      id: 'c2',
      merchantId: 'm1',
      name: 'Sides',
      icon: 'side',
      sortOrder: 1,
    ),
  ],
  'm2': [
    CatalogCategory(
      id: 'c3',
      merchantId: 'm2',
      name: 'Dairy & Bakery',
      icon: 'dairy',
      sortOrder: 0,
    ),
    CatalogCategory(
      id: 'c4',
      merchantId: 'm2',
      name: 'Fresh Produce',
      icon: 'fresh',
      sortOrder: 1,
    ),
  ],
  'm3': [
    CatalogCategory(
      id: 'c5',
      merchantId: 'm3',
      name: 'Medicines',
      icon: 'medicine',
      sortOrder: 0,
    ),
    CatalogCategory(
      id: 'c6',
      merchantId: 'm3',
      name: 'Vitamins & Supplements',
      icon: 'vitamin',
      sortOrder: 1,
    ),
  ],
};
