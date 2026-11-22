class ClientPricedAlert {
  const ClientPricedAlert({
    required this.merchantId,
    required this.merchantName,
    required this.sales,
    required this.totalLines,
    required this.clientPricedLines,
    required this.clientPricedRatio,
  });

  factory ClientPricedAlert.fromJson(Map<String, dynamic> json) {
    return ClientPricedAlert(
      merchantId: json['merchant_id'] as String,
      merchantName: (json['merchant_name'] as String?) ?? '',
      sales: (json['sales'] as num?)?.toInt() ?? 0,
      totalLines: (json['total_lines'] as num?)?.toInt() ?? 0,
      clientPricedLines: (json['client_priced_lines'] as num?)?.toInt() ?? 0,
      clientPricedRatio:
          (json['client_priced_ratio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final String merchantId;
  final String merchantName;
  final int sales;
  final int totalLines;
  final int clientPricedLines;
  final double clientPricedRatio;
}

class InsuranceMismatch {
  const InsuranceMismatch({
    required this.merchantId,
    required this.merchantName,
    required this.insuranceSaleId,
    this.companyId,
    required this.claimedTotal,
    required this.serverTotal,
    required this.companyShare,
    required this.patientShare,
    required this.createdAt,
  });

  factory InsuranceMismatch.fromJson(Map<String, dynamic> json) {
    return InsuranceMismatch(
      merchantId: json['merchant_id'] as String,
      merchantName: (json['merchant_name'] as String?) ?? '',
      insuranceSaleId: (json['insurance_sale_id'] as num?)?.toInt() ?? 0,
      companyId: json['company_id'] as String?,
      claimedTotal: (json['claimed_total'] as num?)?.toDouble() ?? 0.0,
      serverTotal: (json['server_total'] as num?)?.toDouble() ?? 0.0,
      companyShare: (json['company_share'] as num?)?.toDouble() ?? 0.0,
      patientShare: (json['patient_share'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  final String merchantId;
  final String merchantName;
  final int insuranceSaleId;
  final String? companyId;
  final double claimedTotal;
  final double serverTotal;
  final double companyShare;
  final double patientShare;
  final DateTime createdAt;
}
