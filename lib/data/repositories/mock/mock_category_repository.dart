import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/domain/repositories/category_repository.dart';

class MockCategoryRepository implements CategoryRepository {
  final List<Category> _categories = [
    Category(
      id: '1',
      name: 'Groceries',
      icon: 'shopping_cart',
      colorValue: 0xFF4CAF50,
      budget: 500,
      spent: 320,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '2',
      name: 'Utilities',
      icon: 'bolt',
      colorValue: 0xFFFF9800,
      budget: 300,
      spent: 245,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '3',
      name: 'Food & Dining',
      icon: 'restaurant',
      colorValue: 0xFFE91E63,
      budget: 400,
      spent: 280,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '4',
      name: 'Income',
      icon: 'account_balance',
      colorValue: 0xFF2196F3,
      spent: 5000,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '5',
      name: 'Transport',
      icon: 'directions_car',
      colorValue: 0xFF9C27B0,
      budget: 200,
      spent: 145,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '6',
      name: 'Entertainment',
      icon: 'movie',
      colorValue: 0xFFFF5722,
      budget: 150,
      spent: 80,
      createdAt: DateTime(2024),
    ),
    Category(
      id: '7',
      name: 'Shopping',
      icon: 'shopping_bag',
      colorValue: 0xFF795548,
      budget: 300,
      spent: 200,
      createdAt: DateTime(2024),
    ),
  ];

  @override
  Future<List<Category>> getCategories() async {
    return List<Category>.from(_categories);
  }

  @override
  Future<Category> getCategoryById(String id) async {
    return _categories.firstWhere((c) => c.id == id);
  }

  @override
  Future<Category> createCategory({
    required String name,
    required String icon,
    required int colorValue,
    double budget = 0,
  }) async {
    final category = Category(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      icon: icon,
      colorValue: colorValue,
      budget: budget,
      createdAt: DateTime.now(),
    );
    _categories.add(category);
    return category;
  }

  @override
  Future<Category> updateCategory({
    required String id,
    String? name,
    String? icon,
    int? colorValue,
    double? budget,
  }) async {
    final index = _categories.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Category not found');

    final existing = _categories[index];
    final updated = existing.copyWith(
      name: name ?? existing.name,
      icon: icon ?? existing.icon,
      colorValue: colorValue ?? existing.colorValue,
      budget: budget ?? existing.budget,
    );
    _categories[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }
}
