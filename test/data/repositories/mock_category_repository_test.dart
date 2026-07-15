import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/mock/mock_category_repository.dart';

void main() {
  late MockCategoryRepository repo;

  setUp(() {
    repo = MockCategoryRepository();
  });

  group('MockCategoryRepository', () {
    test('getCategories returns categories', () async {
      final categories = await repo.getCategories();
      expect(categories, isNotEmpty);
    });

    test('getCategoryById returns correct category', () async {
      final category = await repo.getCategoryById('1');
      expect(category.id, '1');
      expect(category.name, isNotEmpty);
    });

    test('createCategory adds new category', () async {
      final category = await repo.createCategory(
        name: 'New Category',
        icon: 'star',
        colorValue: 0xFF2196F3,
      );
      expect(category.name, 'New Category');
    });

    test('updateCategory updates existing category', () async {
      final updated = await repo.updateCategory(
        id: '1',
        name: 'Updated Name',
      );
      expect(updated.name, 'Updated Name');
    });

    test('deleteCategory removes category', () async {
      await repo.deleteCategory('99');
      expect(
        () => repo.getCategoryById('99'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
