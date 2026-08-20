import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String merchantId,
    required String categoryId,
    required String name,
    String? description,
    required double price,
    double? originalPrice,
    String? imageUrl,
    @Default([]) List<ProductVariant> variants,
    @Default(true) bool isAvailable,
    @Default(false) bool isFeatured,
    @Default([]) List<String> tags,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

@freezed
class ProductVariant with _$ProductVariant {
  const factory ProductVariant({
    required String id,
    required String productId,
    required String name,
    required double price,
    @Default(true) bool isAvailable,
  }) = _ProductVariant;

  factory ProductVariant.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantFromJson(json);
}
