class DeliveryPricingModel {
  const DeliveryPricingModel({
    required this.serviceType,
    required this.baseFee,
    required this.perKm,
    this.perKg = 0,
    required this.minimumFee,
    this.priorityMultiplier = 1.0,
    this.expressMultiplier = 1.5,
    this.currency = 'EGP',
  });

  final String serviceType;
  final double baseFee;
  final double perKm;
  final double perKg;
  final double minimumFee;
  final double priorityMultiplier;
  final double expressMultiplier;
  final String currency;

  double calculateFee(double distanceKm, {double weightKg = 1.0, String priority = 'standard'}) {
    var fee = baseFee + (perKm * distanceKm) + (perKg * weightKg);
    var multiplier = 1.0;
    if (priority == 'priority') {
      multiplier = priorityMultiplier;
    } else if (priority == 'express') {
      multiplier = expressMultiplier;
    }
    fee *= multiplier;
    if (fee < minimumFee) fee = minimumFee;
    return double.parse(fee.toStringAsFixed(2));
  }
}
