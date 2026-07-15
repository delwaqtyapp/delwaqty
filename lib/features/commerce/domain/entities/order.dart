import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';
part 'order.g.dart';

enum OrderStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('preparing')
  preparing,
  @JsonValue('ready')
  ready,
  @JsonValue('picked_up')
  pickedUp,
  @JsonValue('in_transit')
  inTransit,
  @JsonValue('delivered')
  delivered,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String merchantId,
    required String merchantName,
    @Default([]) List<OrderItem> items,
    required double subtotal,
    @Default(0.0) double deliveryFee,
    @Default(0.0) double discount,
    @Default(0.0) double total,
    required OrderStatus status,
    String? deliveryAddress,
    String? paymentMethod,
    String? specialInstructions,
    DateTime? confirmedAt,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    required String productName,
    String? variantName,
    required int quantity,
    required double unitPrice,
    required double totalPrice,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}
