import 'package:flutter/foundation.dart';
import 'package:delwaqty/data/repositories/admin_repository.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

class AdminService {
  AdminService(this._repository);

  final AdminRepository _repository;

  // ─── Dashboard ────────────────────────────────────────────

  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    try {
      return await _repository.getDashboardMetrics();
    } catch (e) {
      debugPrint('AdminService.getDashboardMetrics error: $e');
      return const AdminDashboardMetrics();
    }
  }

  Future<AdminDashboard?> getDashboardLegacy() async {
    try {
      final metrics = await _repository.getDashboardMetrics();
      return AdminDashboard(
        totalUsers: metrics.totalUsers,
        totalMerchants: metrics.totalMerchants,
        totalOrders: metrics.pendingOrders + metrics.completedDeliveries,
        totalRevenue: metrics.totalRevenue,
        activeDrivers: metrics.activeDrivers,
        pendingOrders: metrics.pendingOrders,
      );
    } catch (e) {
      debugPrint('AdminService.getDashboardLegacy error: $e');
      return null;
    }
  }

  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20}) async {
    try {
      return await _repository.getRecentActivity(limit: limit);
    } catch (e) {
      debugPrint('AdminService.getRecentActivity error: $e');
      return [];
    }
  }

  // ─── Users ────────────────────────────────────────────────

  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      return await _repository.getUsers(search: search);
    } catch (e) {
      debugPrint('AdminService.getUsers error: $e');
      return [];
    }
  }

  Future<AdminUser?> createUser(AdminUser user) async {
    try {
      return await _repository.createUser(user);
    } catch (e) {
      debugPrint('AdminService.createUser error: $e');
      return null;
    }
  }

  Future<AdminUser?> updateUser(AdminUser user) async {
    try {
      return await _repository.updateUser(user);
    } catch (e) {
      debugPrint('AdminService.updateUser error: $e');
      return null;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
      return true;
    } catch (e) {
      debugPrint('AdminService.deleteUser error: $e');
      return false;
    }
  }

  // ─── Merchants ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMerchants({
    String? search,
    String? status,
  }) async {
    try {
      return await _repository.getMerchants(search: search, status: status);
    } catch (e) {
      debugPrint('AdminService.getMerchants error: $e');
      return [];
    }
  }

  Future<bool> updateMerchantStatus(String merchantId, String status) async {
    try {
      await _repository.updateMerchantStatus(merchantId, status);
      return true;
    } catch (e) {
      debugPrint('AdminService.updateMerchantStatus error: $e');
      return false;
    }
  }

  // ─── Orders ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      return await _repository.getOrders(
        search: search,
        status: status,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('AdminService.getOrders error: $e');
      return [];
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _repository.updateOrderStatus(orderId, status);
      return true;
    } catch (e) {
      debugPrint('AdminService.updateOrderStatus error: $e');
      return false;
    }
  }

  // ─── Settings ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    try {
      return await _repository.getSettings();
    } catch (e) {
      debugPrint('AdminService.getSettings error: $e');
      return {};
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _repository.updateSettings(settings);
      return true;
    } catch (e) {
      debugPrint('AdminService.updateSettings error: $e');
      return false;
    }
  }

  // ─── Drivers ──────────────────────────────────────────────

  Future<List<DriverModel>> getActiveDrivers() async {
    try {
      return await _repository.getActiveDrivers();
    } catch (e) {
      debugPrint('AdminService.getActiveDrivers error: $e');
      return [];
    }
  }

  Future<List<DriverModel>> getAllDrivers({String? search, String? status}) async {
    try {
      return await _repository.getAllDrivers(search: search, status: status);
    } catch (e) {
      debugPrint('AdminService.getAllDrivers error: $e');
      return [];
    }
  }

  Future<bool> verifyDriver({
    required String driverId,
    required bool isVerified,
  }) async {
    try {
      await _repository.verifyDriver(
        driverId: driverId,
        isVerified: isVerified,
      );
      return true;
    } catch (e) {
      debugPrint('AdminService.verifyDriver error: $e');
      return false;
    }
  }

  Future<bool> updateDriverOnlineStatus({
    required String driverId,
    required bool isActive,
  }) async {
    try {
      await _repository.updateDriverStatus(
        driverId: driverId,
        isActive: isActive,
      );
      return true;
    } catch (e) {
      debugPrint('AdminService.updateDriverOnlineStatus error: $e');
      return false;
    }
  }

  // ─── Rides ────────────────────────────────────────────────

  Future<List<RideModel>> getRecentRides({String? status}) async {
    try {
      return await _repository.getRecentRides(status: status);
    } catch (e) {
      debugPrint('AdminService.getRecentRides error: $e');
      return [];
    }
  }

  // ─── Deliveries ───────────────────────────────────────────

  Future<List<DeliveryModel>> getRecentDeliveries({String? serviceType}) async {
    try {
      return await _repository.getRecentDeliveries(serviceType: serviceType);
    } catch (e) {
      debugPrint('AdminService.getRecentDeliveries error: $e');
      return [];
    }
  }

  Future<bool> updateDeliveryStatus(String deliveryId, String status) async {
    try {
      await _repository.updateDeliveryStatus(deliveryId, status);
      return true;
    } catch (e) {
      debugPrint('AdminService.updateDeliveryStatus error: $e');
      return false;
    }
  }

  // ─── Revenue & Analytics ──────────────────────────────────

  Future<List<RevenueData>> getRevenueChart({required int days}) async {
    try {
      return await _repository.getRevenueChart(days: days);
    } catch (e) {
      debugPrint('AdminService.getRevenueChart error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPeakHours() async {
    try {
      return await _repository.getPeakHours();
    } catch (e) {
      debugPrint('AdminService.getPeakHours error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopMerchants({int limit = 10}) async {
    try {
      return await _repository.getTopMerchants(limit: limit);
    } catch (e) {
      debugPrint('AdminService.getTopMerchants error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverPerformance({int limit = 10}) async {
    try {
      return await _repository.getDriverPerformance(limit: limit);
    } catch (e) {
      debugPrint('AdminService.getDriverPerformance error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAnalytics({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return await _repository.getAnalytics(from: from, to: to);
    } catch (e) {
      debugPrint('AdminService.getAnalytics error: $e');
      return {};
    }
  }
}
