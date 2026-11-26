import 'package:delwaqty/core/utils/rpc_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/features/admin/domain/repositories/admin_repository.dart'
    as admin;
import 'package:delwaqty/domain/enums/user_type.dart';

class AdminRepository implements admin.AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ─── Dashboard Metrics ────────────────────────────────────

  @override
  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    try {
      // 372: one scoped RPC replaces count_table_rows + bare .count() selects.
      // Owner/country admins get global numbers; region-scoped admins get
      // in-scope counts; anyone else gets zeros (never an error).
      final data = await _supabase.rpc<Map<String, dynamic>>(
        'admin_dashboard_metrics',
      );
      return AdminDashboardMetrics.fromJson(data);
    } catch (e) {
      throw AdminException('Failed to fetch dashboard metrics: $e');
    }
  }

  // ─── Revenue Chart ────────────────────────────────────────

  @override
  Future<List<RevenueData>> getRevenueChart({required int days}) async {
    try {
      final now = DateTime.now();
      final results = <RevenueData>[];

      for (int i = days - 1; i >= 0; i--) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        final nextDay = day.add(const Duration(days: 1));
        final dayStr = day.toIso8601String();
        final nextDayStr = nextDay.toIso8601String();

        final ridesRevenue = await _supabase
            .from('rides')
            .select('fare')
            .eq('status', 'completed')
            .gte('completed_at', dayStr)
            .lt('completed_at', nextDayStr);

        double dayTotal = 0;
        for (final ride in ridesRevenue as List) {
          dayTotal += (ride['fare'] as num?)?.toDouble() ?? 0;
        }

        results.add(RevenueData(date: day, amount: dayTotal));
      }

      return results;
    } catch (e) {
      throw AdminException('Failed to fetch revenue chart: $e');
    }
  }

  // ─── Active Drivers ───────────────────────────────────────

  @override
  Future<List<DriverModel>> getActiveDrivers() async {
    try {
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('is_online', true)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((e) => _mapToDriverModel(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw AdminException('Failed to fetch active drivers: $e');
    }
  }

  // ─── All Drivers ──────────────────────────────────────────

  @override
  Future<List<DriverModel>> getAllDrivers({
    String? search,
    String? status,
  }) async {
    try {
      var query = _supabase.from('drivers').select();

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$search%,phone.ilike.%$search%,vehicle_plate.ilike.%$search%',
        );
      }

      if (status != null && status.isNotEmpty) {
        switch (status) {
          case 'online':
            query = query.eq('is_online', true);
          case 'offline':
            query = query.eq('is_online', false);
          case 'verified':
            query = query.eq('is_verified', true);
          case 'unverified':
            query = query.eq('is_verified', false);
          case 'pending':
            query = query.eq('verification_status', 'pending');
          case 'suspended':
            query = query.eq('is_active', false);
          case 'active':
            query = query.eq('is_active', true);
        }
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((e) => _mapToDriverModel(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw AdminException('Failed to fetch drivers: $e');
    }
  }

  // ─── Verify Driver ────────────────────────────────────────

  @override
  Future<void> verifyDriver({
    required String driverId,
    required bool isVerified,
  }) async {
    try {
      checkedRpcResult(
        await _supabase.rpc(
          'review_driver_application',
          params: {
            'p_driver_id': driverId,
            'p_approve': isVerified,
            'p_reason': isVerified ? null : 'Rejected after document review',
          },
        ),
        onFailure: AdminException.new,
      );
    } catch (e) {
      throw AdminException('Failed to verify driver: $e');
    }
  }

  // ─── Update Driver Status ─────────────────────────────────

  @override
  Future<void> updateDriverStatus({
    required String driverId,
    required bool isActive,
  }) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'is_online': isActive,
            'is_active': isActive,
            'status': isActive ? 'online' : 'offline',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      throw AdminException('Failed to update driver status: $e');
    }
  }

  // ─── Recent Deliveries ────────────────────────────────────

  @override
  Future<List<DeliveryModel>> getRecentDeliveries({
    int limit = 20,
    String? serviceType,
  }) async {
    try {
      var query = _supabase.from('rides').select().neq('service_type', 'ride');

      if (serviceType != null && serviceType.isNotEmpty) {
        query = query.eq('service_type', serviceType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => _mapToDeliveryModel(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw AdminException('Failed to fetch recent deliveries: $e');
    }
  }

  // ─── Peak Hours ───────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getPeakHours() async {
    try {
      final response = await _supabase.rpc('get_peak_hours');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return _getPeakHoursFallback();
    }
  }

  Future<List<Map<String, dynamic>>> _getPeakHoursFallback() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final rides = await _supabase
        .from('rides')
        .select('created_at')
        .gte('created_at', thirtyDaysAgo.toIso8601String());

    final hourCounts = <int, int>{};
    for (final ride in rides as List) {
      final ts = DateTime.parse(ride['created_at'] as String);
      final hour = ts.hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    final peakHours =
        hourCounts.entries
            .map((e) => {'hour': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return peakHours;
  }

  // ─── Top Merchants ────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getTopMerchants({int limit = 10}) async {
    try {
      final rides = await _supabase
          .from('rides')
          .select('merchant_id, fare')
          .neq('service_type', 'ride')
          .not('merchant_id', 'is', null)
          .eq('status', 'completed');

      final merchantRevenue = <String, double>{};
      final merchantTrips = <String, int>{};
      for (final ride in rides as List) {
        final merchantId = ride['merchant_id'] as String;
        final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
        merchantRevenue[merchantId] = (merchantRevenue[merchantId] ?? 0) + fare;
        merchantTrips[merchantId] = (merchantTrips[merchantId] ?? 0) + 1;
      }

      final sortedMerchants = merchantRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topEntries = sortedMerchants.take(limit).toList();
      // 449 app switch: one admin-gated definer RPC replaces the per-row
      // table selects (base-table SELECT is 450 territory). Merchants the
      // caller may not see come back as the 'Unknown' fallback, same as the
      // old per-row catch.
      final contactRows = topEntries.isEmpty
          ? const <dynamic>[]
          : await _supabase.rpc(
              'admin_get_merchant_contacts',
              params: {'p_merchant_ids': topEntries.map((e) => e.key).toList()},
            ) as List;
      final contactsById = <String, Map<String, dynamic>>{
        for (final raw in contactRows)
          (raw as Map<String, dynamic>)['id'] as String:
              Map<String, dynamic>.from(raw),
      };

      final topMerchants = <Map<String, dynamic>>[];
      for (final entry in topEntries) {
        final merchantData = contactsById[entry.key];
        topMerchants.add({
          'merchant_id': entry.key,
          'name': merchantData?['name'] ?? 'Unknown',
          'email': merchantData?['email'],
          'phone': merchantData?['phone'],
          'total_revenue': entry.value,
          'total_deliveries': merchantTrips[entry.key] ?? 0,
          'currency': 'ج.م',
        });
      }

      return topMerchants;
    } catch (e) {
      throw AdminException('Failed to fetch top merchants: $e');
    }
  }

  // ─── Driver Performance ───────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getDriverPerformance({
    int limit = 10,
  }) async {
    try {
      final rides = await _supabase
          .from('rides')
          .select('driver_id, fare, status')
          .not('driver_id', 'is', null);

      final driverStats = <String, Map<String, dynamic>>{};
      for (final ride in rides as List) {
        final driverId = ride['driver_id'] as String;
        final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
        final status = ride['status'] as String;

        if (!driverStats.containsKey(driverId)) {
          driverStats[driverId] = {
            'completed': 0,
            'cancelled': 0,
            'total_revenue': 0.0,
          };
        }

        if (status == 'completed') {
          driverStats[driverId]!['completed'] =
              (driverStats[driverId]!['completed'] as int) + 1;
          driverStats[driverId]!['total_revenue'] =
              (driverStats[driverId]!['total_revenue'] as double) + fare;
        } else if (status == 'cancelled') {
          driverStats[driverId]!['cancelled'] =
              (driverStats[driverId]!['cancelled'] as int) + 1;
        }
      }

      final sortedDrivers = driverStats.entries.toList()
        ..sort(
          (a, b) => (b.value['total_revenue'] as double).compareTo(
            a.value['total_revenue'] as double,
          ),
        );

      final results = <Map<String, dynamic>>[];
      for (final entry in sortedDrivers.take(limit)) {
        try {
          final driverData = await _supabase
              .from('drivers')
              .select('id, full_name, phone, rating, is_online')
              .eq('id', entry.key)
              .maybeSingle();

          results.add({
            'driver_id': entry.key,
            'full_name': driverData?['full_name'] ?? 'Unknown',
            'phone': driverData?['phone'],
            'rating': driverData?['rating'] ?? 0,
            'is_online': driverData?['is_online'] ?? false,
            'completed_trips': entry.value['completed'],
            'cancelled_trips': entry.value['cancelled'],
            'total_revenue': entry.value['total_revenue'],
            'currency': 'ج.م',
          });
        } catch (_) {
          results.add({
            'driver_id': entry.key,
            'full_name': 'Unknown',
            'completed_trips': entry.value['completed'],
            'cancelled_trips': entry.value['cancelled'],
            'total_revenue': entry.value['total_revenue'],
            'currency': 'ج.م',
          });
        }
      }

      return results;
    } catch (e) {
      throw AdminException('Failed to fetch driver performance: $e');
    }
  }

  // ─── Recent Activity ──────────────────────────────────────

  @override
  Future<List<AdminActivityLog>> getRecentActivity({int limit = 20}) async {
    try {
      final response = await _supabase
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

  // ─── Users ────────────────────────────────────────────────

  @override
  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      var query = _supabase
          .from('admin_users')
          .select('id, full_name, email, role, status, last_login, created_at');

      if (search != null && search.isNotEmpty) {
        query = query.or('full_name.ilike.%$search%,email.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) {
        return AdminUser(
          id: json['id'] as String,
          name: json['full_name'] as String,
          email: json['email'] as String,
          role: AdminRole.fromDb(json['role'] as String?),
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

  @override
  Future<AdminUser> createUser(AdminUser user) async {
    try {
      final response = await _supabase
          .from('admin_users')
          .insert({
            'full_name': user.name,
            'email': user.email,
            'role': user.role.toDb(),
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

  @override
  Future<AdminUser> updateUser(AdminUser user) async {
    try {
      final response = await _supabase
          .from('admin_users')
          .update({
            'full_name': user.name,
            'email': user.email,
            'role': user.role.toDb(),
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

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.rpc(
        'owner_delete_member',
        params: {
          'p_member_id': userId,
          'p_reason': 'Deleted via Admin Repository',
        },
      );
    } catch (e) {
      throw AdminException('Failed to delete user: $e');
    }
  }

  // ─── Merchants ────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getMerchants({
    String? search,
    String? status,
  }) async {
    try {
      // Region-scoped server side (371): the public-catalog SELECT policy on
      // merchants exposes every active merchant to any signed-in user, so a
      // bare table select leaks the whole country to scoped admins.
      final response = await _supabase.rpc(
        'admin_list_merchants',
        params: {'p_search': search, 'p_status': status},
      );
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch merchants: $e');
    }
  }

  @override
  Future<void> updateMerchantStatus(String merchantId, String status) async {
    try {
      await _supabase
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

  // ─── Content moderation ─────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getMerchantProducts(
    String merchantId,
  ) async {
    try {
      // 449 app switch: admin reads the catalog through the definer RPC
      // (base-table SELECT is 450 territory; same shape and ordering).
      final response = await _supabase.rpc(
        'admin_get_merchant_products',
        params: {'p_merchant_id': merchantId},
      );
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch merchant products: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentMerchantReviews({
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select(
            'id, rating, comment, created_at, merchant_id, product_id, user_id',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch merchant reviews: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentServiceReviews({
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('service_reviews')
          .select(
            'id, rating, comment, created_at, category_type, provider_id, user_name',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch service reviews: $e');
    }
  }

  @override
  Future<bool> deleteMerchantReview(String reviewId) async {
    try {
      return await _supabase.rpc<bool>(
        'admin_delete_merchant_review',
        params: {'p_review_id': reviewId},
      );
    } catch (e) {
      throw AdminException('Failed to delete merchant review: $e');
    }
  }

  @override
  Future<bool> deleteServiceReview(String reviewId) async {
    try {
      return await _supabase.rpc<bool>(
        'admin_delete_service_review',
        params: {'p_review_id': reviewId},
      );
    } catch (e) {
      throw AdminException('Failed to delete service review: $e');
    }
  }

  @override
  Future<bool> deleteProduct(String productId) async {
    try {
      return await _supabase.rpc<bool>(
        'admin_delete_product',
        params: {'p_product_id': productId},
      );
    } catch (e) {
      throw AdminException('Failed to delete product: $e');
    }
  }

  @override
  Future<bool> upsertProduct(Map<String, dynamic> product) async {
    try {
      final response = await _supabase.rpc(
        'admin_upsert_product',
        params: {
          'p_id': product['id'],
          'p_merchant_id': product['merchant_id'],
          'p_name': product['name'],
          'p_description': product['description'],
          'p_price': product['price'],
          'p_compare_at_price': product['compare_at_price'],
          'p_category': product['category'],
          'p_image_url': product['image_url'],
          'p_is_available': product['is_available'] ?? true,
          'p_stock_quantity': product['stock_quantity'] ?? 0,
        },
      );
      return (response as Map<String, dynamic>)['success'] == true;
    } catch (e) {
      throw AdminException('Failed to save product: $e');
    }
  }

  @override
  Future<bool> deleteMerchant(String merchantId) async {
    try {
      return await _supabase.rpc<bool>(
        'admin_delete_merchant',
        params: {'p_merchant_id': merchantId},
      );
    } catch (e) {
      throw AdminException('Failed to delete merchant: $e');
    }
  }

  // ─── Orders ───────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getOrders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('orders').select('''
        id, merchant_id, total_amount, status, created_at,
        users!inner(id, full_name, email)
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

      // 449/451 app switch: merchant names resolve through the admin-gated,
      // region-scoped contacts RPC (merchants base-table SELECT is 450
      // territory; the RPC has no status filter, so suspended/inactive
      // merchant order history is preserved). Orders whose merchant the
      // caller may not see drop out, mirroring the old inner join under
      // merchant RLS.
      final rows = List<Map<String, dynamic>>.from(response as List);
      final merchantIds = <String>{
        for (final r in rows)
          if (r['merchant_id'] != null) r['merchant_id'] as String,
      };
      final contacts = merchantIds.isEmpty
          ? const <dynamic>[]
          : await _supabase.rpc(
              'admin_get_merchant_contacts',
              params: {'p_merchant_ids': merchantIds.toList()},
            ) as List;
      final contactsById = <String, Map<String, dynamic>>{
        for (final raw in contacts)
          (raw as Map<String, dynamic>)['id'] as String:
              Map<String, dynamic>.from(raw),
      };

      return [
        for (final r in rows)
          if (contactsById.containsKey(r['merchant_id']))
            {
              ...r,
              'merchants': {
                'id': r['merchant_id'],
                'name': contactsById[r['merchant_id']]!['name'],
              },
            },
      ];
    } catch (e) {
      throw AdminException('Failed to fetch orders: $e');
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _supabase
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

  // ─── Settings ─────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _supabase
          .from('platform_settings')
          .select()
          .single();

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AdminException('Failed to fetch settings: $e');
    }
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _supabase.from('platform_settings').upsert({
        'id': 'default',
        ...settings,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw AdminException('Failed to update settings: $e');
    }
  }

  // ─── Legacy Rides ─────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getRides({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('rides').select('''
        id, pickup_latitude, pickup_longitude, dropoff_latitude,
        dropoff_longitude, fare, status, service_type, created_at,
        rider_id, driver_id, ride_type, distance, payment_method
      ''');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch rides: $e');
    }
  }

  // ─── Legacy Deliveries ────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getDeliveries({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('rides').select().neq('service_type', 'ride');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw AdminException('Failed to fetch deliveries: $e');
    }
  }

  @override
  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    try {
      await _supabase
          .from('rides')
          .update({'status': status})
          .eq('id', deliveryId);
    } catch (e) {
      throw AdminException('Failed to update delivery status: $e');
    }
  }

  // ─── Analytics ────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> getAnalytics({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final String? fromStr = from?.toIso8601String();
      final String? toStr = to?.toIso8601String();

      // RPC params must be passed via `params:` — applying .eq() to an RPC
      // call filters on a non-existent result column and the dates never
      // reach the function.
      final response = await _supabase.rpc(
        'get_admin_analytics',
        params: {'date_from': ?fromStr, 'date_to': ?toStr},
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AdminException('Failed to fetch analytics: $e');
    }
  }

  // ─── Account Verification ────────────────────────────────

  @override
  Future<List<VerificationRequest>> getVerificationRequests() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('verification_status', 'pending')
          .inFilter('user_type', ['provider', 'delivery', 'merchant', 'driver'])
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        return VerificationRequest(
          userId: json['id'] as String,
          email: json['email'] as String,
          fullName: (json['full_name'] ?? json['name']) as String?,
          phone: json['phone'] as String?,
          userType: UserType.fromCode(
            (json['user_type'] ?? json['role']) as String?,
          ),
          idCardUrl: json['id_card_url'] as String?,
          profilePhotoUrl: json['profile_photo_url'] as String?,
          createdAt: DateTime.parse(json['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw AdminException('Failed to fetch verification requests: $e');
    }
  }

  @override
  Future<VerificationDocuments> getVerificationDocuments(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select(
            'id_card_url, profile_photo_url, trade_license_url, driving_license_url',
          )
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return const VerificationDocuments();
      return VerificationDocuments(
        idCardUrl: row['id_card_url'] as String?,
        profilePhotoUrl: row['profile_photo_url'] as String?,
        tradeLicenseUrl: row['trade_license_url'] as String?,
        drivingLicenseUrl: row['driving_license_url'] as String?,
      );
    } catch (e) {
      throw AdminException('Failed to fetch verification documents: $e');
    }
  }

  @override
  Future<void> approveVerification(String userId) async {
    try {
      await _supabase.rpc(
        'decide_user_verification',
        params: {
          'p_user_id': userId,
          // decide_user_verification accepts ONLY 'approve' / 'reject'.
          // The database enum for users.verification_status is
          // approved/rejected, and the RPC translates it internally.
          'p_decision': 'approve',
        },
      );
    } catch (e) {
      throw AdminException('Failed to approve verification: $e');
    }
  }

  @override
  Future<void> rejectVerification(
    String userId, {
    required String reason,
  }) async {
    try {
      await _supabase.rpc(
        'decide_user_verification',
        params: {
          'p_user_id': userId,
          'p_decision': 'reject',
          'p_reason': reason,
        },
      );
    } catch (e) {
      throw AdminException('Failed to reject verification: $e');
    }
  }

  // ─── Private Mappers ──────────────────────────────────────

  DriverModel _mapToDriverModel(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      isAvailable: (json['is_online'] as bool?) ?? false,
      isActive: (json['status'] as String?) == 'online',
      isVerified: (json['is_verified'] as bool?) ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalTrips:
          (json['total_trips'] as int?) ??
          (json['total_deliveries'] as int?) ??
          0,
      lastLocationLat: (json['current_latitude'] as num?)?.toDouble(),
      lastLocationLng: (json['current_longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  DeliveryModel _mapToDeliveryModel(Map<String, dynamic> json) {
    return DeliveryModel(
      id: json['id'] as String,
      userId: json['rider_id'] as String?,
      driverId: json['driver_id'] as String?,
      serviceType: (json['service_type'] as String?) ?? 'courier',
      status: json['status'] as String,
      senderName: json['pickup_notes'] as String?,
      receiverName: json['dropoff_notes'] as String?,
      itemDescription:
          (json['items_summary'] as String?) ??
          (json['pickup_notes'] as String?),
      itemWeight: (json['weight_kg'] as num?)?.toDouble(),
      itemUnit: json['weight_kg'] != null ? 'kg' : null,
      totalPrice: (json['fare'] as num?)?.toDouble(),
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      dropoffLatitude: (json['dropoff_latitude'] as num).toDouble(),
      dropoffLongitude: (json['dropoff_longitude'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
