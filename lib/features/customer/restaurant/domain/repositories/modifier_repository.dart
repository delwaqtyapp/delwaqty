import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';

abstract interface class ModifierRepository {
  Future<List<ProductModifier>> getModifiers(String productId);

  /// Required modifier groups: group id -> option ids (empty when none).
  Future<Map<String, Set<String>>> getRequiredGroupOptions(String productId);

  /// All modifier groups with selection rules (required, max selections)
  /// and option membership, for picker enforcement.
  Future<List<ModifierGroupInfo>> getModifierGroups(String productId);
}
