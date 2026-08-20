class DeliveryRequest {
  const DeliveryRequest({
    required this.id,
    required this.deliveryId,
    required this.driverId,
    required this.status,
    this.distanceKm,
    this.etaMinutes,
    required this.offeredAt,
    required this.expiresAt,
  });

  final String id;
  final String deliveryId;
  final String driverId;
  final String status;
  final double? distanceKm;
  final int? etaMinutes;
  final DateTime offeredAt;
  final DateTime expiresAt;

  Duration get remaining {
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => remaining == Duration.zero;
}
