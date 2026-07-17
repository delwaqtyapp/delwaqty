import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

/// Repository for admin operations with Supabase backend.
///
/// Provides CRUD operations for users, merchants, orders, and dashboard metrics.
class AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ─── Dashboard ──────────────────────────────────────────────

  /// Fetches aggregated dashboard metrics.
  Future<AdminDashboard> getDashboardMetrics() async {
    try {
      final usersResponse = await _client.from('users').select('id').count();
      final merchantsResponse = await _client
          .from('merchants')
          .select('id')
          .count();
      final ordersResponse = await _client.from('orders').select('id').count();
      final deliveredOrders = await _client
          .from('orders')
          .select('total_amount')
          .eq('status', 'delivered');
      final activeDriversResponse = await _client
          .from('drivers')
          .select('id')
          .eq('is_active', true)
          .count();
      final pendingOrdersResponse = await _client
          .from('orders')
          .select('id')
          .eq('status', 'pending')
          .count();

      final totalRevenue = (deliveredOrders as List).fold<double>(
        0,
        (sum, order) =>
            sum + ((order['total_amount'] as num?)?.toDouble() ?? 0),
      );

      return AdminDashboard(
        totalUsers: usersResponse.count,
        totalMerchants: merchantsResponse.count,
        totalOrders: ordersResponse.count,
        totalRevenue: totalRevenue,
        activeDrivers: activeDriversResponse.count,
        pendingOrders: pendingOrdersResponse.count,
      );
    } catch (e) {
      throw AdminException('Failed to fetch dashboard metrics: $e');
    }
  }

  /// Fetches recent activity logs.
  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20}) async {
    try {
      final response = await _client
          .from('activity_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List).map((json) {
        return AdminActivityLog(
          id: json['id'] as String,
          userId: json['user_id'] as String,
          action: json['action'] as String,
          resource: json['resource'] as String,
          timestamp: DateTime.parse(json['timestamp'] as String),
          details: json['details'] as String?,
        );
      }).toList();
    } catch (e) {
      throw AdminException('Failed to fetch activity logs: $e');
    }
  }

  // ─── Users ──────────────────────────────────────────────────

  /// Fetches all admin users with optional search.
  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      var query = _client.from('admin_users').select();

      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,email.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) {
        return AdminUser(
          id: json['id'] as String,
          name: json['name'] as String,
          email: json['email'] as String,
          role: AdminRole.values.firstWhere(
            (r) => r.name == json['role'],
            orElse: () => AdminRole.support,
          ),
          status: AdminUserStatus.values.firstWhere(
            (s) => s.name == json['status'],
            orElse: () => AdminUserStatus.pending,
          ),
          lastLogin: json['last_login'] != null
              ? DateTime.parse(json['last_login'] as String)
              : null,
          createdAt: DateTime.parse(json['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw AdminException('Failed to fetch users: $e');
    }
  }

  /// Creates a new admin user.
  Future<AdminUser> createUser(AdminUser user) async {
    try {
      final response = await _client
          .from('admin_users')
          .insert({
            'name': user.name,
            'email': user.email,
            'role': user.role.name,
            'status': user.status.name,
          })
          .select()
          .single();

      return AdminUser(
        id: response['id'] as String,
        name: response['name'] as String,
        email: response['email'] as String,
        role: user.role,
        status: user.status,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e) {
      throw AdminException('Failed to create user: $e');
    }
  }

  /// Updates an existing admin user.
  Future<AdminUser> updateUser(AdminUser user) async {
    try {
      final response = await _client
          .from('admin_users')
          .update({
            'name': user.name,
            'email': user.email,
            'role': user.role.name,
            'status': user.status.name,
          })
          .eq('id', user.id)
          .select()
          .single();

      return AdminUser(
        id: response['id'] as String,
        name: response['name'] as String,
        email: response['email'] as String,
        role: user.role,
        status: user.status,
        lastLogin: user.lastLogin,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (e) {
      throw AdminException('Failed to update user: $e');
    }
  }

  /// Deletes an admin user.
  Future<void> deleteUser(String userId) async {
    try {
      await _client.from('admin_users').delete().eq('id', userId);
    } catch (e) {
      throw AdminException('Failed to delete user: $e');
    }
  }

  // ─── Merchants ──────────────────────────────────────────────

  /// Fetches all merchants with optional search and status filter.
  Future<List<Map<String, dynamic>>> getMerchants({
    String? search,
    String? status,
  }) async {
    try {
      var query = _client.from('merchants').select();

      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,email.ilike.%$search%');
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch merchants: $e');
    }
  }

  /// Updates merchant status (verify, suspend, etc.).
  Future<void> updateMerchantStatus(String merchantId, String status) async {
    try {
      await _client
          .from('merchants')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', merchantId);
    } catch (e) {
      throw AdminException('Failed to update merchant status: $e');
    }
  }

  // ─── Orders ─────────────────────────────────────────────────

  /// Fetches all orders with optional filters.
  Future<List<Map<String, dynamic>>> getOrders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('orders').select('''
        id, total_amount, status, created_at,
        users!inner(id, name, email),
        merchants!inner(id, name)
      ''');

      if (search != null && search.isNotEmpty) {
        query = query.or('id.ilike.%$search%');
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch orders: $e');
    }
  }

  /// Updates order status.
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _client
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      throw AdminException('Failed to update order status: $e');
    }
  }

  // ─── Settings ───────────────────────────────────────────────

  /// Fetches platform settings.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _client
          .from('platform_settings')
          .select()
          .single();

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AdminException('Failed to fetch settings: $e');
    }
  }

  /// Updates platform settings.
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _client.from('platform_settings').upsert({
        'id': 'default',
        ...settings,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw AdminException('Failed to update settings: $e');
    }
  }
}

/// Exception thrown by admin operations.
class AdminException implements Exception {
  const AdminException(this.message);
  final String message;

  @override
  String toString() => 'AdminException: $message';
}
