import 'package:delwaqty/features/restaurant/domain/entities/product_modifier.dart';

abstract interface class ModifierRepository {
  Future<List<ProductModifier>> getModifiers(String productId);
  Future<ProductModifier> createModifier(ProductModifier modifier);
  Future<ProductModifier> updateModifier(ProductModifier modifier);
  Future<void> deleteModifier(String id);
}
