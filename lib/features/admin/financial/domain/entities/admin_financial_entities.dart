class AdminTopupRequest {

  const AdminTopupRequest({
    required this.id,
    required this.accountId,
    this.regionId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.transferReference,
    this.proofPath,
    this.message,
    this.createdAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  factory AdminTopupRequest.fromJson(Map<String, dynamic> json) => AdminTopupRequest(
        id: json['id'].toString(),
        accountId: json['account_id'].toString(),
        regionId: json['region_id']?.toString(),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'SAR',
        status: json['status'] as String? ?? 'pending',
        paymentMethod: json['payment_method'] as String? ?? 'bank_transfer',
        transferReference: json['transfer_reference'] as String?,
        proofPath: json['proof_path'] as String?,
        message: json['message'] as String?,
        createdAt: json['created_at']?.toString(),
        reviewedBy: json['reviewed_by']?.toString(),
        rejectionReason: json['rejection_reason'] as String?,
      );
  final String id;
  final String accountId;
  final String? regionId;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String? transferReference;
  final String? proofPath;
  final String? message;
  final String? createdAt;
  final String? reviewedBy;
  final String? rejectionReason;
}

class CollectionSummary {

  const CollectionSummary({
    this.regionId,
    required this.today,
    required this.week,
    required this.month,
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.settled,
    required this.outstanding,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> json) => CollectionSummary(
        regionId: json['region_id']?.toString(),
        today: _toDouble(json['today']),
        week: _toDouble(json['week']),
        month: _toDouble(json['month']),
        total: _toDouble(json['total']),
        pending: _toDouble(json['pending']),
        approved: _toDouble(json['approved']),
        rejected: _toDouble(json['rejected']),
        settled: _toDouble(json['settled']),
        outstanding: _toDouble(json['outstanding']),
      );
  final String? regionId;
  final double today;
  final double week;
  final double month;
  final double total;
  final double pending;
  final double approved;
  final double rejected;
  final double settled;
  final double outstanding;

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
}

class CollectionRecord {

  const CollectionRecord({
    required this.id,
    required this.adminId,
    this.regionId,
    required this.accountId,
    this.topupRequestId,
    required this.amount,
    required this.currency,
    this.reference,
    this.receivedAt,
    required this.status,
    this.settlementId,
  });

  factory CollectionRecord.fromJson(Map<String, dynamic> json) => CollectionRecord(
        id: json['id'].toString(),
        adminId: json['admin_id'].toString(),
        regionId: json['region_id']?.toString(),
        accountId: json['account_id'].toString(),
        topupRequestId: json['topup_request_id']?.toString(),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'SAR',
        reference: json['reference'] as String?,
        receivedAt: json['received_at']?.toString(),
        status: json['status'] as String? ?? 'collected',
        settlementId: json['settlement_id']?.toString(),
      );
  final String id;
  final String adminId;
  final String? regionId;
  final String accountId;
  final String? topupRequestId;
  final double amount;
  final String currency;
  final String? reference;
  final String? receivedAt;
  final String status;
  final String? settlementId;
}

class SettlementRecord {

  const SettlementRecord({
    required this.id,
    required this.adminId,
    this.regionId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.reference,
    required this.status,
    this.createdAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  factory SettlementRecord.fromJson(Map<String, dynamic> json) => SettlementRecord(
        id: json['id'].toString(),
        adminId: json['admin_id'].toString(),
        regionId: json['region_id']?.toString(),
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'SAR',
        paymentMethod: json['payment_method'] as String? ?? 'bank_transfer',
        reference: json['reference'] as String?,
        status: json['status'] as String? ?? 'pending',
        createdAt: json['created_at']?.toString(),
        reviewedBy: json['reviewed_by']?.toString(),
        rejectionReason: json['rejection_reason'] as String?,
      );
  final String id;
  final String adminId;
  final String? regionId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? reference;
  final String status;
  final String? createdAt;
  final String? reviewedBy;
  final String? rejectionReason;
}

class ReceivingAccount {

  const ReceivingAccount({
    required this.id,
    required this.methodType,
    required this.displayName,
    this.accountName,
    this.accountNumber,
    this.walletNumber,
    this.instructions,
    required this.isActive,
  });

  factory ReceivingAccount.fromJson(Map<String, dynamic> json) => ReceivingAccount(
        id: json['id'].toString(),
        methodType: json['method_type'] as String? ?? 'bank_transfer',
        displayName: json['display_name'] as String? ?? '',
        accountName: json['account_name'] as String?,
        accountNumber: json['account_number'] as String?,
        walletNumber: json['wallet_number'] as String?,
        instructions: json['instructions'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
  final String id;
  final String methodType;
  final String displayName;
  final String? accountName;
  final String? accountNumber;
  final String? walletNumber;
  final String? instructions;
  final bool isActive;
}

class GraceAccount {

  const GraceAccount({
    required this.userId,
    required this.graceLimit,
    required this.graceUsed,
  });

  factory GraceAccount.fromJson(Map<String, dynamic> json) => GraceAccount(
        userId: json['user_id'].toString(),
        graceLimit: (json['grace_limit'] as num?)?.toInt() ?? 0,
        graceUsed: (json['grace_used'] as num?)?.toInt() ?? 0,
      );
  final String userId;
  final int graceLimit;
  final int graceUsed;

  int get remaining => (graceLimit - graceUsed).clamp(0, graceLimit);
}
