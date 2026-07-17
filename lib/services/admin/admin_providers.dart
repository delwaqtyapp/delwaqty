import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/services/admin/admin_service.dart';

/// Provider for dashboard metrics.
final dashboardMetricsProvider = FutureProvider<AdminDashboard?>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getDashboardMetrics();
});

/// Provider for recent activity.
final recentActivityProvider = FutureProvider<List<AdminActivityLog>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getRecentActivity();
});

/// Provider for admin users list.
final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getUsers();
});

/// Provider for merchants list.
final adminMerchantsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getMerchants();
});

/// Provider for orders list.
final adminOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getOrders();
});

/// Provider for platform settings.
final platformSettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final adminService = ref.watch(adminServiceProvider);
  return adminService.getSettings();
});
