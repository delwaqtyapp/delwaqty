/// One line of the live itemized invoice of an ask-anything ride (436):
/// the driver records each item at the shop with its real price; the
/// customer approves or rejects it before it is bought.
class CourierInvoiceItem {
  const CourierInvoiceItem({
    required this.id,
    required this.rideId,
    required this.shopName,
    required this.productName,
    this.unit,
    this.quantity,
    required this.price,
    this.receiptPhotoUrl,
    required this.status,
    this.createdAt,
  });

  factory CourierInvoiceItem.fromRow(Map<String, dynamic> row) =>
      CourierInvoiceItem(
        id: row['id'] as String,
        rideId: row['ride_id'] as String,
        shopName: row['shop_name'] as String? ?? '',
        productName: row['product_name'] as String? ?? '',
        unit: row['unit'] as String?,
        quantity: (row['quantity'] as num?)?.toDouble(),
        price: (row['price'] as num).toDouble(),
        receiptPhotoUrl: row['receipt_photo_url'] as String?,
        status: row['status'] as String? ?? 'pending',
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      );

  final String id;
  final String rideId;
  final String shopName;
  final String productName;
  final String? unit;
  final double? quantity;
  final double price;
  final String? receiptPhotoUrl;

  /// pending | approved | rejected | cancelled
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}
