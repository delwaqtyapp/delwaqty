/// Cash-handoff state for one delivery, as the assigned captain sees it.
/// Backed by the `driver_cash_collection_state` RPC (migration 392), which
/// only answers the assigned driver or the owner.
class CashCollectionState {
  const CashCollectionState({
    required this.rideId,
    required this.collected,
    this.orderId,
    this.rideStatus,
    this.paymentMethod,
    this.paymentStatus,
    this.amount,
    this.currency = 'EGP',
  });

  factory CashCollectionState.fromJson(Map<String, dynamic> json) {
    return CashCollectionState(
      rideId: json['ride_id'] as String,
      orderId: json['order_id'] as String?,
      rideStatus: json['ride_status'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      collected: json['collected'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EGP',
    );
  }

  final String rideId;
  final String? orderId;
  final String? rideStatus;
  final String? paymentMethod;
  final String? paymentStatus;

  /// True once the captain tapped "تم التحصيل" and the server stamped it.
  final bool collected;

  /// What the customer physically hands over: the linked order's total for
  /// commerce deliveries, the fare for a pure courier ride.
  final double? amount;
  final String currency;

  bool get isCash => paymentMethod == 'cash';
}

/// Outcome of the "تم التحصيل" tap (`confirm_cash_collection`).
class CashCollectionResult {
  const CashCollectionResult({
    required this.ok,
    required this.code,
    this.amount,
  });

  factory CashCollectionResult.fromJson(Map<String, dynamic> json) {
    return CashCollectionResult(
      ok: json['ok'] as bool? ?? false,
      code: json['code'] as String? ?? 'UNKNOWN',
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }

  final bool ok;
  final String code;
  final double? amount;

  /// Both a fresh COLLECTED and an idempotent ALREADY_COLLECTED replay mean
  /// the cash is marked collected.
  bool get collected => ok && (code == 'COLLECTED' || code == 'ALREADY_COLLECTED');
}

/// The delivery ride linked to a commerce order, for the customer's
/// post-collection driver rating (migration 392).
class OrderDeliveryRide {
  const OrderDeliveryRide({
    required this.id,
    required this.status,
    this.driverId,
    this.driverName,
    this.paymentMethod,
    this.paymentStatus,
    this.cashCollectedAt,
  });

  factory OrderDeliveryRide.fromRow(Map<String, dynamic> row) {
    return OrderDeliveryRide(
      id: row['id'] as String,
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      status: row['status'] as String? ?? 'searching',
      paymentMethod: row['payment_method'] as String?,
      paymentStatus: row['payment_status'] as String?,
      cashCollectedAt: row['cash_collected_at'] != null
          ? DateTime.parse(row['cash_collected_at'] as String)
          : null,
    );
  }

  final String id;
  final String? driverId;
  final String? driverName;
  final String status;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? cashCollectedAt;

  bool get isCompleted => status == 'completed';

  /// The customer rates the driver only once cash was collected; non-cash
  /// deliveries stay rateable at completion, as before. The rule is the
  /// collection STAMP, the same one the ride_ratings RLS uses (migration
  /// 392) — payment_status alone is not enough, because historical paid
  /// rows may carry no stamp until the server replay/backfill heals them.
  bool get rateable =>
      isCompleted &&
      (paymentMethod != 'cash' || cashCollectedAt != null);
}
