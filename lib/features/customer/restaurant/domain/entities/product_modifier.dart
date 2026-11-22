import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_modifier.freezed.dart';
part 'product_modifier.g.dart';

@freezed
abstract class ProductModifier with _$ProductModifier {
  const factory ProductModifier({
    required String id,
    required String productId,
    required String name,
    String? description,
    @Default(0.0) double priceAdjustment,
    @Default(true) bool isAvailable,
    @Default(0) int sortOrder,
    required DateTime createdAt,
  }) = _ProductModifier;

  factory ProductModifier.fromJson(Map<String, dynamic> json) =>
      _$ProductModifierFromJson(json);
}

/// Modifier group selection rules for the customer picker
/// (product_modifier_groups): which options belong to the group, whether a
/// pick is required, and the maximum number of picks (0 = unlimited).
class ModifierGroupInfo {
  const ModifierGroupInfo({
    required this.id,
    required this.isRequired,
    required this.maxSelections,
    required this.optionIds,
  });

  final String id;
  final bool isRequired;
  final int maxSelections;
  final Set<String> optionIds;
}
