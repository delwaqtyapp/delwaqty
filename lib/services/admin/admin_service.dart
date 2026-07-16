import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/data/repositories/admin_repository.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

/// Provider for AdminRepository.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

/// Provider for AdminService.
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(adminRepositoryProvider));
});

/// High-level admin service that wraps the repository.
///
/// Provides business logic and state management for admin operations.
class AdminService {
  AdminService(this._repository);

  final AdminRepository _repository;

  // ─── Dashboard ──────────────────────────────────────────────

  /// Fetches dashboard metrics with error handling.
  Future<AdminDashboard?> getDashboardMetrics() async {
    try {
      return await _repository.getDashboardMetrics();
    } catch (e) {
      return null;
    }
  }

  /// Fetches recent activity with error handling.
  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20}) async {
    try {
      return await _repository.getRecentActivity(limit: limit);
    } catch (e) {
      return [];
    }
  }

  // ─── Users ──────────────────────────────────────────────────

  /// Fetches users with search.
  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      return await _repository.getUsers(search: search);
    } catch (e) {
      return [];
    }
  }

  /// Creates a user.
  Future<AdminUser?> createUser(AdminUser user) async {
    try {
      return await _repository.createUser(user);
    } catch (e) {
      return null;
    }
  }

  /// Updates a user.
  Future<AdminUser?> updateUser(AdminUser user) async {
    try {
      return await _repository.updateUser(user);
    } catch (e) {
      return null;
    }
  }

  /// Deletes a user.
  Future<bool> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Merchants ──────────────────────────────────────────────

  /// Fetches merchants with filters.
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

  /// Updates merchant status.
  Future<bool> updateMerchantStatus(String merchantId, String status) async {
    try {
      await _repository.updateMerchantStatus(merchantId, status);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Orders ─────────────────────────────────────────────────

  /// Fetches orders with filters.
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

  /// Updates order status.
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _repository.updateOrderStatus(orderId, status);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Settings ───────────────────────────────────────────────

  /// Fetches platform settings.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      return await _repository.getSettings();
    } catch (e) {
      return {};
    }
  }

  /// Updates platform settings.
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _repository.updateSettings(settings);
      return true;
    } catch (e) {
      return false;
    }
  }
}
