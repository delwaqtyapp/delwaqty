class GraceInfo {
  const GraceInfo({
    required this.limit,
    required this.used,
    required this.remaining,
  });

  factory GraceInfo.fromJson(Map<String, dynamic> json) => GraceInfo(
        limit: (json['grace_limit'] as num?)?.toInt() ?? 0,
        used: (json['grace_used'] as num?)?.toInt() ?? 0,
        remaining: (json['grace_remaining'] as num?)?.toInt() ?? 0,
      );

  final int limit;
  final int used;
  final int remaining;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );

  final String id;
  final String type;
  final double amount;
  final String description;
  final double balanceAfter;
  final DateTime createdAt;
}

class TopupRequest {
  const TopupRequest({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.transferReference,
    required this.createdAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory TopupRequest.fromJson(Map<String, dynamic> json) => TopupRequest(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'SAR',
        status: json['status'] as String? ?? 'pending',
        paymentMethod: json['payment_method'] as String? ?? '',
        transferReference: json['transfer_reference'] as String? ?? '',
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        reviewedAt: json['reviewed_at'] is String
            ? DateTime.parse(json['reviewed_at'] as String)
            : null,
        rejectionReason: json['rejection_reason'] as String?,
      );

  final String id;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String transferReference;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
}

class FinancialSummary {
  const FinancialSummary({
    required this.balance,
    required this.graceLimit,
    required this.graceUsed,
    required this.graceRemaining,
    required this.commissionRate,
    required this.pendingTopups,
    required this.recentTransactions,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) => FinancialSummary(
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        graceLimit: (json['grace_limit'] as num?)?.toInt() ?? 0,
        graceUsed: (json['grace_used'] as num?)?.toInt() ?? 0,
        graceRemaining: (json['grace_remaining'] as num?)?.toInt() ?? 0,
        commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
        pendingTopups: (json['pending_topups'] as num?)?.toInt() ?? 0,
        recentTransactions: (json['recent_transactions'] as List? ?? [])
            .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final double balance;
  final int graceLimit;
  final int graceUsed;
  final int graceRemaining;
  final double commissionRate;
  final int pendingTopups;
  final List<WalletTransaction> recentTransactions;
}
