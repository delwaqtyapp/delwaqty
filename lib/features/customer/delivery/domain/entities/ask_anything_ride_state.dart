/// The ask-anything (436) columns of one ride row, streamed live to the
/// negotiation and invoice cards. Null while the ride is not an
/// ask-anything courier ride.
class AskAnythingRideState {
  const AskAnythingRideState({
    required this.rideId,
    required this.status,
    required this.shopCount,
    required this.quoteLocked,
    required this.goodsTotal,
    required this.shoppingFinished,
    this.fare,
    this.driverId,
  });

  factory AskAnythingRideState.fromRow(Map<String, dynamic> row) =>
      AskAnythingRideState(
        rideId: row['id'] as String,
        status: row['status'] as String? ?? 'searching',
        shopCount: (row['courier_shop_count'] as num?)?.toInt() ?? 1,
        quoteLocked: row['courier_quote_locked'] as bool? ?? false,
        goodsTotal: (row['courier_goods_total'] as num?)?.toDouble() ?? 0,
        shoppingFinished: row['courier_shopping_finished'] as bool? ?? false,
        fare: (row['fare'] as num?)?.toDouble(),
        driverId: row['driver_id'] as String?,
      );

  final String rideId;
  final String status;
  final int shopCount;
  final bool quoteLocked;
  final double goodsTotal;
  final bool shoppingFinished;
  final double? fare;
  final String? driverId;

  /// The 15 + 5 per extra shop floor of any quote or counter (#211);
  /// the server enforces the same bound, this is the client-side check.
  double get quoteBaseline => 15 + 5 * (shopCount - 1);
}
