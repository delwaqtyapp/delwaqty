import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_modifier.freezed.dart';
part 'product_modifier.g.dart';

@freezed
class ProductModifier with _$ProductModifier {
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
