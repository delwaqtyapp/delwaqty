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
      return null;
    }
  }

  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20}) async {
    try {
      return await _repository.getRecentActivity(limit: limit);
    } catch (e) {
      return [];
    }
  }

  // ─── Users ────────────────────────────────────────────────

  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      return await _repository.getUsers(search: search);
    } catch (e) {
      return [];
    }
  }

  Future<AdminUser?> createUser(AdminUser user) async {
    try {
      return await _repository.createUser(user);
    } catch (e) {
      return null;
    }
  }

  Future<AdminUser?> updateUser(AdminUser user) async {
    try {
      return await _repository.updateUser(user);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
      return true;
    } catch (e) {
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
      return [];
    }
  }

  Future<bool> updateMerchantStatus(String merchantId, String status) async {
    try {
      await _repository.updateMerchantStatus(merchantId, status);
      return true;
    } catch (e) {
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
      return [];
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _repository.updateOrderStatus(orderId, status);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Settings ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    try {
      return await _repository.getSettings();
    } catch (e) {
      return {};
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _repository.updateSettings(settings);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Drivers ──────────────────────────────────────────────

  Future<List<DriverModel>> getActiveDrivers() async {
    try {
      return await _repository.getActiveDrivers();
    } catch (e) {
      return [];
    }
  }

  Future<List<DriverModel>> getAllDrivers({String? search, String? status}) async {
    try {
      return await _repository.getAllDrivers(search: search, status: status);
    } catch (e) {
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
      return false;
    }
  }

  // ─── Rides ────────────────────────────────────────────────

  Future<List<RideModel>> getRecentRides({String? status}) async {
    try {
      return await _repository.getRecentRides(status: status);
    } catch (e) {
      return [];
    }
  }

  // ─── Deliveries ───────────────────────────────────────────

  Future<List<DeliveryModel>> getRecentDeliveries({String? serviceType}) async {
    try {
      return await _repository.getRecentDeliveries(serviceType: serviceType);
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateDeliveryStatus(String deliveryId, String status) async {
    try {
      await _repository.updateDeliveryStatus(deliveryId, status);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Revenue & Analytics ──────────────────────────────────

  Future<List<RevenueData>> getRevenueChart({required int days}) async {
    try {
      return await _repository.getRevenueChart(days: days);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPeakHours() async {
    try {
      return await _repository.getPeakHours();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopMerchants({int limit = 10}) async {
    try {
      return await _repository.getTopMerchants(limit: limit);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverPerformance({int limit = 10}) async {
    try {
      return await _repository.getDriverPerformance(limit: limit);
    } catch (e) {
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
      return {};
    }
  }
}
