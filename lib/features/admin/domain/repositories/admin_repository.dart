import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

abstract class AdminRepository {
  Future<AdminDashboardMetrics> getDashboardMetrics();
  Future<List<RevenueData>> getRevenueChart({required int days});
  Future<List<DriverModel>> getActiveDrivers();
  Future<List<DriverModel>> getAllDrivers({String? search, String? status});
  Future<void> verifyDriver({required String driverId, required bool isVerified});
  Future<void> updateDriverStatus({required String driverId, required bool isActive});
  Future<List<DeliveryModel>> getRecentDeliveries({int limit = 20, String? serviceType});
  Future<List<Map<String, dynamic>>> getPeakHours();
  Future<List<Map<String, dynamic>>> getTopMerchants({int limit = 10});
  Future<List<Map<String, dynamic>>> getDriverPerformance({int limit = 10});
  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20});
  Future<List<AdminUser>> getUsers({String? search});
  Future<AdminUser> createUser(AdminUser user);
  Future<AdminUser> updateUser(AdminUser user);
  Future<void> deleteUser(String userId);
  Future<List<Map<String, dynamic>>> getMerchants({String? search, String? status});
  Future<void> updateMerchantStatus(String merchantId, String status);
  Future<List<Map<String, dynamic>>> getOrders({String? search, String? status, int limit = 50, int offset = 0});
  Future<void> updateOrderStatus(String orderId, String status);
  Future<Map<String, dynamic>> getSettings();
  Future<void> updateSettings(Map<String, dynamic> settings);
  Future<List<Map<String, dynamic>>> getRides({String? status, int limit = 50, int offset = 0});
  Future<List<Map<String, dynamic>>> getDeliveries({String? status, int limit = 50, int offset = 0});
  Future<void> updateDeliveryStatus(String deliveryId, String status);
  Future<Map<String, dynamic>> getAnalytics({DateTime? from, DateTime? to});
  Future<List<VerificationRequest>> getVerificationRequests();
  Future<void> approveVerification(String userId);
  Future<void> rejectVerification(String userId, {required String reason});
}
