import 'package:delwaqty/features/customer/commerce/domain/entities/catalog_category.dart';

abstract interface class CatalogCategoryRepository {
  Future<List<CatalogCategory>> getCategories(String merchantId);
  Future<CatalogCategory?> getCategoryById(String id);
}
