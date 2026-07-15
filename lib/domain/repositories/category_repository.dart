import 'package:delwaqty/domain/entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories();

  Future<Category> getCategoryById(String id);

  Future<Category> createCategory({
    required String name,
    required String icon,
    required int colorValue,
    double budget = 0,
  });

  Future<Category> updateCategory({
    required String id,
    String? name,
    String? icon,
    int? colorValue,
    double? budget,
  });

  Future<void> deleteCategory(String id);
}
