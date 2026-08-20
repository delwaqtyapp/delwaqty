class DriverPerformance {
  const DriverPerformance({
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.rating,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.todayRides,
    required this.todayEarnings,
    required this.weekEarnings,
    required this.monthEarnings,
    required this.balance,
    required this.bonusBalance,
    required this.incentiveBalance,
    required this.pendingWithdrawals,
    this.currency = 'EGP',
  });

  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final double rating;
  final double acceptanceRate;
  final double cancellationRate;
  final int todayRides;
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final double balance;
  final double bonusBalance;
  final double incentiveBalance;
  final double pendingWithdrawals;
  final String currency;

  static const empty = DriverPerformance(
    totalTrips: 0,
    completedTrips: 0,
    cancelledTrips: 0,
    rating: 0,
    acceptanceRate: 100,
    cancellationRate: 0,
    todayRides: 0,
    todayEarnings: 0,
    weekEarnings: 0,
    monthEarnings: 0,
    balance: 0,
    bonusBalance: 0,
    incentiveBalance: 0,
    pendingWithdrawals: 0,
  );
}
