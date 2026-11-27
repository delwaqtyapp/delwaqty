import 'package:supabase_flutter/supabase_flutter.dart';

const refundReasonCodes = [
  'missing_item',
  'wrong_item',
  'quality',
  'late',
  'damaged',
  'other',
];

/// A refund_requests row as the customer sees it (RLS: own rows only).
class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.status,
    required this.amount,
    this.approvedAmount,
    this.reviewNote,
  });

  final String id;
  final String orderId;
  final String status; // pending | approved | rejected
  final num amount;
  final num? approvedAmount;
  final String? reviewNote;

  factory RefundRequest.fromRow(Map<String, dynamic> row) => RefundRequest(
    id: row['id'] as String,
    orderId: row['order_id'] as String,
    status: row['status'] as String,
    amount: row['amount'] as num,
    approvedAmount: row['approved_amount'] as num?,
    reviewNote: row['review_note'] as String?,
  );
}

/// Raised when an RPC answers `{ok:false, code}`.
class RefundException implements Exception {
  RefundException(this.code);
  final String code;
  @override
  String toString() => 'refund refused: $code';
}

/// Throws [RefundException] unless the RPC result says ok.
Map<String, dynamic> unwrapRefundResult(Object? res) {
  final map = Map<String, dynamic>.from(res as Map);
  if (map['ok'] != true) {
    throw RefundException((map['code'] as String?) ?? 'UNKNOWN');
  }
  return map;
}

class RefundRequestsApi {
  RefundRequestsApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Latest request for an order, or null.
  Future<RefundRequest?> latestForOrder(String orderId) async {
    final rows = await _client
        .from('refund_requests')
        .select('id,order_id,status,amount,approved_amount,review_note')
        .eq('order_id', orderId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return RefundRequest.fromRow(Map<String, dynamic>.from(rows.first));
  }

  Future<void> request({
    required String orderId,
    required String reasonCode,
    String? details,
  }) async {
    final res = await _client.rpc(
      'request_refund',
      params: {
        'p_order_id': orderId,
        'p_reason_code': reasonCode,
        'p_details': details,
      },
    );
    unwrapRefundResult(res);
  }

  /// Admin queue (needs the review_refund financial permission).
  Future<List<Map<String, dynamic>>> adminList({
    String status = 'pending',
  }) async {
    final res = await _client.rpc(
      'admin_list_refund_requests',
      params: {'p_status': status},
    );
    final map = unwrapRefundResult(res);
    return (map['requests'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> adminReview({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    final res = await _client.rpc(
      'admin_review_refund',
      params: {'p_request_id': requestId, 'p_approve': approve, 'p_note': note},
    );
    unwrapRefundResult(res);
  }
}
