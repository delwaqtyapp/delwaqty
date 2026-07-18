class DriverStats {
  const DriverStats({
    required this.todayRides,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.balance,
    required this.pendingWithdrawals,
    required this.totalTrips,
    required this.rating,
    required this.acceptanceRate,
    required this.currency,
  });

  final int todayRides;
  final double todayEarnings;
  final double weekEarnings;
  final double balance;
  final double pendingWithdrawals;
  final int totalTrips;
  final double rating;
  final double acceptanceRate;
  final String currency;

  static const empty = DriverStats(
    todayRides: 0,
    todayEarnings: 0,
    weekEarnings: 0,
    balance: 0,
    pendingWithdrawals: 0,
    totalTrips: 0,
    rating: 0,
    acceptanceRate: 100,
    currency: 'EGP',
  );
}

class DriverEarning {
  const DriverEarning({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    this.rideId,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final double amount;
  final String currency;
  final String? rideId;
  final String? description;
  final DateTime createdAt;
}
