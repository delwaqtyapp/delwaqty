import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/category.dart';

void main() {
  group('Category', () {
    test('fromJson creates Category from JSON', () {
      final json = {
        'id': '1',
        'name': 'Food',
        'icon': 'restaurant',
        'colorValue': 0xFFE91E63,
        'budget': 400.0,
        'spent': 280.0,
        'createdAt': '2024-01-15T10:00:00.000',
      };

      final category = Category.fromJson(json);
      expect(category.id, '1');
      expect(category.name, 'Food');
      expect(category.budget, 400.0);
      expect(category.spent, 280.0);
    });

    test('toJson serializes correctly', () {
      final category = Category(
        id: '1',
        name: 'Food',
        icon: 'restaurant',
        colorValue: 0xFFE91E63,
        createdAt: DateTime(2024, 1, 15),
      );

      final json = category.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'Food');
      expect(json['colorValue'], 0xFFE91E63);
    });

    test('categoryColor extension returns correct color', () {
      final category = Category(
        id: '1',
        name: 'Test',
        icon: 'test',
        colorValue: 0xFFE91E63,
        createdAt: DateTime(2024),
      );

      expect(category.categoryColor.toARGB32(), 0xFFE91E63);
    });
  });
}
