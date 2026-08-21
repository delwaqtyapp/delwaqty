import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/data/repositories/admin_repository.dart';
import 'package:delwaqty/services/admin/admin_service.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

// ─── Repository & Service Providers ────────────────────────

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(adminRepositoryProvider));
});

// ─── Dashboard Metrics ─────────────────────────────────────

final dashboardMetricsProvider = FutureProvider<AdminDashboardMetrics>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDashboardMetrics();
});

// ─── Recent Activity ───────────────────────────────────────

final recentActivityProvider = FutureProvider<List<AdminActivityLog>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentActivity();
});

// ─── Admin Users ───────────────────────────────────────────

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getUsers();
});

// ─── Merchants ─────────────────────────────────────────────

final adminMerchantsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getMerchants();
});

// ─── Orders ────────────────────────────────────────────────

final adminOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getOrders();
});

// ─── Platform Settings ─────────────────────────────────────

final platformSettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getSettings();
});

// ─── Commission Rules (052) ────────────────────────────────

final commissionRulesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.rpc('list_commission_rules');
  return Map<String, dynamic>.from(response as Map);
});

// ─── Pending Approval Requests (052) ───────────────────────

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

// ─── Active Drivers ────────────────────────────────────────

final activeDriversProvider = FutureProvider<List<DriverModel>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getActiveDrivers();
});

// ─── All Drivers ───────────────────────────────────────────

final allDriversProvider =
    FutureProvider.family<List<DriverModel>, String?>((ref, search) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getAllDrivers(search: search);
});

// ─── Recent Deliveries ─────────────────────────────────────

final recentDeliveriesProvider =
    FutureProvider.family<List<DeliveryModel>, String?>((ref, serviceType) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentDeliveries(serviceType: serviceType);
});

// ─── Revenue Chart ─────────────────────────────────────────

final revenueChartProvider =
    FutureProvider.family<List<RevenueData>, int>((ref, days) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRevenueChart(days: days);
});

// ─── Peak Hours ────────────────────────────────────────────

final peakHoursProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getPeakHours();
});

// ─── Top Merchants ─────────────────────────────────────────

final topMerchantsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getTopMerchants();
});

// ─── Driver Performance ────────────────────────────────────

final driverPerformanceProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDriverPerformance();
});

// ─── Verification Requests ─────────────────────────────────

final verificationRequestsProvider = FutureProvider<List<VerificationRequest>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getVerificationRequests();
});
