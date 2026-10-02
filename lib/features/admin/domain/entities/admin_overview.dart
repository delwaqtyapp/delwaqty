/// Aggregated platform counters shown on the admin dashboard overview.
class AdminOverviewStats {
  const AdminOverviewStats({
    required this.users,
    required this.merchants,
    required this.orders,
    required this.drivers,
    required this.serviceBookings,
  });

  final int users;
  final int merchants;
  final int orders;
  final int drivers;
  final int serviceBookings;
}