import 'dart:async';
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

// ─── SOS Alerts ─────────────────────────────────────────────

final adminSosAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getSosAlerts();
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

final adminMerchantsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, AdminMerchantsQuery>((
      ref,
      query,
    ) async {
      final adminService = ref.watch(adminServiceProvider);
      return adminService.getMerchants(
        search: query.search,
        status: query.status,
      );
    });

/// Query parameters for the admin merchants list.
class AdminMerchantsQuery {
  const AdminMerchantsQuery({this.search, this.status});

  final String? search;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is AdminMerchantsQuery &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(search, status);
}

final adminMerchantsSearchProvider =
    NotifierProvider<AdminMerchantsSearchNotifier, String>(
      AdminMerchantsSearchNotifier.new,
    );

class AdminMerchantsSearchNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() => '';

  void update(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      state = value;
    });
  }
}

// ─── Content Moderation ───────────────────────────────────

final adminMerchantReviewsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentMerchantReviews();
});

final adminServiceReviewsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentServiceReviews();
});

// ─── Orders ────────────────────────────────────────────────

final adminOrdersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, AdminOrdersQuery>((
      ref,
      query,
    ) async {
      final adminService = ref.watch(adminServiceProvider);
      return adminService.getOrders(
        search: query.search,
        status: query.status,
      );
    });

/// Query parameters for the admin orders list (search + status filter).
/// Previously the page re-fetched with no arguments at all, so typing in
/// the search box only re-ran the same unfiltered query and the filter
/// sheet did nothing at all.
class AdminOrdersQuery {
  const AdminOrdersQuery({this.search, this.status});

  final String? search;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is AdminOrdersQuery && other.search == search && other.status == status;

  @override
  int get hashCode => Object.hash(search, status);
}

/// Debounces the free-text search so every keystroke does not fire an RPC.
final adminOrdersSearchProvider =
    NotifierProvider<AdminOrdersSearchNotifier, String>(AdminOrdersSearchNotifier.new);

class AdminOrdersSearchNotifier extends Notifier<String> {
  Timer? _debounce;

  @override
  String build() => '';

  void update(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      state = value;
    });
  }
}

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
