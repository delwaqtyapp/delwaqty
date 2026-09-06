import 'package:freezed_annotation/freezed_annotation.dart';

part 'merchant_order.freezed.dart';
part 'merchant_order.g.dart';

@freezed
abstract class MerchantOrder with _$MerchantOrder {
  const factory MerchantOrder({
    required String id,
    required String customerId,
    String? customerName,
    @Default([]) List<MerchantOrderItem> items,
    required double totalAmount,
    required String status,
    required DateTime createdAt,
    String? deliveryAddress,
    String? notes,
  }) = _MerchantOrder;

  factory MerchantOrder.fromJson(Map<String, dynamic> json) =>
      _$MerchantOrderFromJson(json);
}

@freezed
abstract class MerchantOrderItem with _$MerchantOrderItem {
  const factory MerchantOrderItem({
    required String productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    @Default([]) List<String> modifiers,
  }) = _MerchantOrderItem;

  factory MerchantOrderItem.fromJson(Map<String, dynamic> json) =>
      _$MerchantOrderItemFromJson(json);
}
