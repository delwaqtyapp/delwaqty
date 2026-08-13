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

  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();
      final monthStart = DateTime(now.year, now.month).toIso8601String();

      final countResults = await Future.wait([
        _supabase.rpc<int>('count_table_rows', params: {'table_name': 'users'}),
        _supabase.rpc<int>('count_table_rows', params: {'table_name': 'drivers'}),
        _supabase.rpc<int>('count_table_rows', params: {'table_name': 'merchants'}),
      ]);

      final metrics = await Future.wait([
        _supabase
            .from('drivers')
            .select('id')
            .eq('is_online', true)
            .count(),
        _supabase
            .from('drivers')
            .select('id')
            .eq('verification_status', 'pending')
            .count(),
        _supabase
            .from('rides')
            .select('id')
            .eq('service_type', 'ride')
            .count(),
        _supabase
            .from('rides')
            .select('id')
            .inFilter('status', ['searching', 'matched', 'arrived', 'inTrip'])
            .count(),
        _supabase
            .from('rides')
            .select('id')
            .neq('service_type', 'ride')
            .count(),
        _supabase
            .from('orders')
            .select('id')
            .eq('status', 'pending')
            .count(),
        _supabase
            .from('rides')
            .select('id')
            .neq('service_type', 'ride')
            .eq('status', 'completed')
            .count(),
        _supabase
            .from('users')
            .select('id')
            .gte('created_at', todayStart)
            .count(),
        _supabase
            .from('users')
            .select('id')
            .gte('created_at', monthStart)
            .count(),
      ]);

      final revenueResults = await Future.wait([
        _supabase
            .from('rides')
            .select('fare')
            .eq('status', 'completed'),
        _supabase
            .from('rides')
            .select('fare')
            .neq('service_type', 'ride')
            .eq('status', 'completed'),
        _supabase
            .from('rides')
            .select('fare')
            .eq('status', 'completed')
            .gte('completed_at', todayStart),
        _supabase
            .from('rides')
            .select('fare')
            .neq('service_type', 'ride')
            .eq('status', 'completed')
            .gte('completed_at', todayStart),
        _supabase
            .from('rides')
            .select('fare')
            .eq('status', 'completed')
            .gte('completed_at', monthStart),
        _supabase
            .from('rides')
            .select('fare')
            .neq('service_type', 'ride')
            .eq('status', 'completed')
            .gte('completed_at', monthStart),
      ]);

      double totalRevenue = 0;
      for (final ride in revenueResults[0] as List) {
        totalRevenue += (ride['fare'] as num?)?.toDouble() ?? 0;
      }
      for (final delivery in revenueResults[1] as List) {
        totalRevenue += (delivery['fare'] as num?)?.toDouble() ?? 0;
      }

      double revenueToday = 0;
      for (final ride in revenueResults[2] as List) {
        revenueToday += (ride['fare'] as num?)?.toDouble() ?? 0;
      }
      for (final delivery in revenueResults[3] as List) {
        revenueToday += (delivery['fare'] as num?)?.toDouble() ?? 0;
      }

      double revenueThisMonth = 0;
      for (final ride in revenueResults[4] as List) {
        revenueThisMonth += (ride['fare'] as num?)?.toDouble() ?? 0;
      }
      for (final delivery in revenueResults[5] as List) {
        revenueThisMonth += (delivery['fare'] as num?)?.toDouble() ?? 0;
      }

      return AdminDashboardMetrics(
        totalUsers: countResults[0],
        totalDrivers: countResults[1],
        totalMerchants: countResults[2],
        activeDrivers: metrics[0].count,
        pendingVerifications: metrics[1].count,
        totalRides: metrics[2].count,
        activeRides: metrics[3].count,
        totalDeliveries: metrics[4].count,
        pendingOrders: metrics[5].count,
        completedDeliveries: metrics[6].count,
        totalRevenue: totalRevenue,
        revenueToday: revenueToday,
        revenueThisMonth: revenueThisMonth,
        newUsersToday: metrics[7].count,
        newUsersThisMonth: metrics[8].count,
      );
    } catch (e) {
      throw AdminException('Failed to fetch dashboard metrics: $e');
    }
  }

  // ─── Revenue Chart ────────────────────────────────────────

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

  Future<void> verifyDriver({
    required String driverId,
    required bool isVerified,
  }) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'is_verified': isVerified,
            'verification_status': isVerified ? 'verified' : 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      throw AdminException('Failed to verify driver: $e');
    }
  }

  // ─── Update Driver Status ─────────────────────────────────

  Future<void> updateDriverStatus({
    required String driverId,
    required bool isActive,
  }) async {
    try {
      await _supabase
          .from('drivers')
          .update({
            'is_online': isActive,
            'status': isActive ? 'online' : 'offline',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);
    } catch (e) {
      throw AdminException('Failed to update driver status: $e');
    }
  }

  // ─── Recent Rides ─────────────────────────────────────────

  Future<List<RideModel>> getRecentRides({
    int limit = 20,
    String? status,
  }) async {
    try {
      var query = _supabase.from('rides').select().eq('service_type', 'ride');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => _mapToRideModel(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      throw AdminException('Failed to fetch recent rides: $e');
    }
  }

  // ─── Recent Deliveries ────────────────────────────────────

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

      final topMerchants = <Map<String, dynamic>>[];
      for (final entry in sortedMerchants.take(limit)) {
        try {
          final merchantData = await _supabase
              .from('merchants')
              .select('id, name, email, phone')
              .eq('id', entry.key)
              .maybeSingle();

          topMerchants.add({
            'merchant_id': entry.key,
            'name': merchantData?['name'] ?? 'Unknown',
            'email': merchantData?['email'],
            'phone': merchantData?['phone'],
            'total_revenue': entry.value,
            'total_deliveries': merchantTrips[entry.key] ?? 0,
            'currency': 'ج.م',
          });
        } catch (_) {
          topMerchants.add({
            'merchant_id': entry.key,
            'name': 'Unknown',
            'total_revenue': entry.value,
            'total_deliveries': merchantTrips[entry.key] ?? 0,
            'currency': 'ج.م',
          });
        }
      }

      return topMerchants;
    } catch (e) {
      throw AdminException('Failed to fetch top merchants: $e');
    }
  }

  // ─── Driver Performance ───────────────────────────────────

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

  Future<List<AdminUser>> getUsers({String? search}) async {
    try {
      var query = _supabase.from('admin_users').select();

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

  Future<AdminUser> createUser(AdminUser user) async {
    try {
      final response = await _supabase
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

  Future<AdminUser> updateUser(AdminUser user) async {
    try {
      final response = await _supabase
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

  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.from('admin_users').delete().eq('id', userId);
    } catch (e) {
      throw AdminException('Failed to delete user: $e');
    }
  }

  // ─── Merchants ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMerchants({
    String? search,
    String? status,
  }) async {
    try {
      var query = _supabase.from('merchants').select();

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

  // ─── Orders ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('orders').select('''
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

  Future<Map<String, dynamic>> getAnalytics({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final String? fromStr = from?.toIso8601String();
      final String? toStr = to?.toIso8601String();

      var query = _supabase.rpc('get_admin_analytics');

      if (fromStr != null) {
        query = query.eq('date_from', fromStr);
      }
      if (toStr != null) {
        query = query.eq('date_to', toStr);
      }

      final response = await query;
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
          .inFilter('user_type', ['provider', 'delivery'])
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
  Future<void> approveVerification(String userId) async {
    try {
      await _supabase
          .from('users')
          .update({
            'verification_status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw AdminException('Failed to approve verification: $e');
    }
  }

  @override
  Future<void> rejectVerification(String userId) async {
    try {
      await _supabase
          .from('users')
          .update({
            'verification_status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
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

  RideModel _mapToRideModel(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      userId: json['rider_id'] as String?,
      driverId: json['driver_id'] as String?,
      serviceType: (json['service_type'] as String?) ?? 'ride',
      status: json['status'] as String,
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      dropoffLatitude: (json['dropoff_latitude'] as num).toDouble(),
      dropoffLongitude: (json['dropoff_longitude'] as num).toDouble(),
      fare: (json['fare'] as num?)?.toDouble(),
      distanceKm: (json['distance'] as num?)?.toDouble(),
      durationMinutes: json['estimated_minutes'] as int?,
      isScheduled: json['scheduled_at'] != null,
      scheduledTime: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
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
