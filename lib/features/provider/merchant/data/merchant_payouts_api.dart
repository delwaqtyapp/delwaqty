import 'package:supabase_flutter/supabase_flutter.dart';

/// Raised when a payout RPC answers `{ok:false, code}`.
class PayoutException implements Exception {
  PayoutException(this.code);
  final String code;
  @override
  String toString() => 'payout refused: $code';
}

Map<String, dynamic> unwrapPayoutResult(Object? res) {
  final map = Map<String, dynamic>.from(res as Map);
  if (map['ok'] != true) {
    throw PayoutException((map['code'] as String?) ?? 'UNKNOWN');
  }
  return map;
}

class LedgerEntry {
  const LedgerEntry({
    required this.type,
    required this.amount,
    required this.createdAt,
    this.description,
  });

  final String type; // credit | debit | reversal
  final num amount;
  final DateTime createdAt;
  final String? description;

  /// Credits add to the balance; debits and reversals subtract (the server
  /// computes the balance the same way).
  bool get isCredit => type == 'credit';

  factory LedgerEntry.fromRow(Map<String, dynamic> row) => LedgerEntry(
    type: row['entry_type'] as String,
    amount: row['amount'] as num,
    createdAt: DateTime.parse(row['created_at'] as String),
    description: row['description'] as String?,
  );
}

class MerchantLedger {
  const MerchantLedger({required this.balance, required this.entries});
  final num balance;
  final List<LedgerEntry> entries;

  factory MerchantLedger.fromResult(Map<String, dynamic> map) => MerchantLedger(
    balance: map['balance'] as num,
    entries: (map['entries'] as List<dynamic>)
        .map((e) => LedgerEntry.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class PayoutRequestRow {
  const PayoutRequestRow({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String id;
  final num amount;
  final String status; // pending | approved | rejected
  final DateTime createdAt;
  final String? rejectionReason;

  factory PayoutRequestRow.fromRow(Map<String, dynamic> row) =>
      PayoutRequestRow(
        id: row['id'] as String,
        amount: row['amount'] as num,
        status: row['status'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        rejectionReason: row['rejection_reason'] as String?,
      );
}

class MerchantPayoutsApi {
  MerchantPayoutsApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MerchantLedger> ledger() async => MerchantLedger.fromResult(
    unwrapPayoutResult(await _client.rpc('get_my_merchant_ledger')),
  );

  /// Own requests (RLS: merchant owner only), newest first.
  Future<List<PayoutRequestRow>> myRequests() async {
    final rows = await _client
        .from('merchant_payout_requests')
        .select('id,amount,status,created_at,rejection_reason')
        .order('created_at', ascending: false)
        .limit(20);
    return rows
        .map((e) => PayoutRequestRow.fromRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> requestPayout(
    num amount, {
    required String idempotencyKey,
  }) async {
    unwrapPayoutResult(
      await _client.rpc(
        'merchant_request_payout',
        params: {'p_amount': amount, 'p_idempotency_key': idempotencyKey},
      ),
    );
  }

  /// Admin queue (platform-global; the server checks the admin scope).
  Future<List<Map<String, dynamic>>> adminList({
    String status = 'pending',
  }) async {
    final map = unwrapPayoutResult(
      await _client.rpc(
        'admin_list_payout_requests',
        params: {'p_status': status},
      ),
    );
    return (map['requests'] as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> adminReview({
    required String requestId,
    required bool approve,
    String? reason,
  }) async {
    unwrapPayoutResult(
      await _client.rpc(
        'admin_review_payout',
        params: {
          'p_request_id': requestId,
          'p_approve': approve,
          'p_reason': reason,
        },
      ),
    );
  }
}

String payoutErrorKey(Object e) => e is PayoutException ? e.code : '';
