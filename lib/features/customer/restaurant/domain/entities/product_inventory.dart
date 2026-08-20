import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_inventory.freezed.dart';
part 'product_inventory.g.dart';

@freezed
class ProductInventory with _$ProductInventory {
  const factory ProductInventory({
    required String id,
    required String productId,
    required String merchantId,
    @Default(0) int stockQuantity,
    @Default(0) int reservedQuantity,
    @Default(10) int lowStockThreshold,
    @Default(true) bool isInStock,
    DateTime? updatedAt,
  }) = _ProductInventory;

  factory ProductInventory.fromJson(Map<String, dynamic> json) =>
      _$ProductInventoryFromJson(json);
}
