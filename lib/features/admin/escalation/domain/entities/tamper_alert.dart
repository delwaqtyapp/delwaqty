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
