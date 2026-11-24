/// A delivery-price quote on an ask-anything ride (436). The driver
/// opens; the customer answers or counters through the same table.
class CourierQuote {
  const CourierQuote({
    required this.id,
    required this.rideId,
    required this.proposedByRole,
    required this.amount,
    this.note,
    required this.status,
    this.createdAt,
  });

  factory CourierQuote.fromRow(Map<String, dynamic> row) => CourierQuote(
    id: row['id'] as String,
    rideId: row['ride_id'] as String,
    proposedByRole: row['proposed_by_role'] as String? ?? 'driver',
    amount: (row['amount'] as num).toDouble(),
    note: row['note'] as String?,
    status: row['status'] as String? ?? 'pending',
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String)
        : null,
  );

  final String id;
  final String rideId;

  /// driver | customer
  final String proposedByRole;
  final double amount;
  final String? note;

  /// pending | accepted | rejected | superseded
  final String status;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isFromDriver => proposedByRole == 'driver';
}
