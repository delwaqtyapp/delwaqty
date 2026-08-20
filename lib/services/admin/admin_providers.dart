import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/data/repositories/admin_repository.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

// â”€â”€â”€ Repository & Service Providers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(adminRepositoryProvider));
});

// â”€â”€â”€ Dashboard Metrics â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final dashboardMetricsProvider = FutureProvider<AdminDashboardMetrics>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDashboardMetrics();
});

// â”€â”€â”€ Recent Activity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final recentActivityProvider = FutureProvider<List<AdminActivityLog>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentActivity();
});

// â”€â”€â”€ Admin Users â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getUsers();
});

// â”€â”€â”€ Merchants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final adminMerchantsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getMerchants();
});

// â”€â”€â”€ Orders â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final adminOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getOrders();
});

// â”€â”€â”€ Platform Settings â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final platformSettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getSettings();
});

// â”€â”€â”€ Commission Rules (052) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final commissionRulesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.rpc('list_commission_rules');
  return Map<String, dynamic>.from(response as Map);
});

// â”€â”€â”€ Pending Approval Requests (052) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final pendingApprovalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.rpc('list_approval_requests');
  if (response == null) {
    return [];
  }
  final data = (response as Map)['requests'] as List;
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

// â”€â”€â”€ Active Drivers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final activeDriversProvider = FutureProvider<List<DriverModel>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getActiveDrivers();
});

// â”€â”€â”€ All Drivers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final allDriversProvider =
    FutureProvider.family<List<DriverModel>, String?>((ref, search) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getAllDrivers(search: search);
});

// â”€â”€â”€ Recent Rides â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final recentRidesProvider =
    FutureProvider.family<List<RideModel>, String?>((ref, status) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentRides(status: status);
});

// â”€â”€â”€ Recent Deliveries â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final recentDeliveriesProvider =
    FutureProvider.family<List<DeliveryModel>, String?>((ref, serviceType) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentDeliveries(serviceType: serviceType);
});

// â”€â”€â”€ Revenue Chart â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final revenueChartProvider =
    FutureProvider.family<List<RevenueData>, int>((ref, days) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRevenueChart(days: days);
});

// â”€â”€â”€ Peak Hours â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final peakHoursProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getPeakHours();
});

// â”€â”€â”€ Top Merchants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final topMerchantsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getTopMerchants();
});

// â”€â”€â”€ Driver Performance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final driverPerformanceProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDriverPerformance();
});

// â”€â”€â”€ Verification Requests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final verificationRequestsProvider = FutureProvider<List<VerificationRequest>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getVerificationRequests();
});
