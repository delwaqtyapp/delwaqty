import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('AdminRole', () {
    test('enum has all values', () {
      expect(AdminRole.values.length, 4);
      expect(AdminRole.superAdmin.name, 'superAdmin');
      expect(AdminRole.admin.name, 'admin');
      expect(AdminRole.moderator.name, 'moderator');
      expect(AdminRole.support.name, 'support');
    });
  });

  group('AdminUserStatus', () {
    test('enum has all values', () {
      expect(AdminUserStatus.values.length, 4);
      expect(AdminUserStatus.active.name, 'active');
      expect(AdminUserStatus.suspended.name, 'suspended');
      expect(AdminUserStatus.pending.name, 'pending');
      expect(AdminUserStatus.deactivated.name, 'deactivated');
    });
  });

  group('PermissionLevel', () {
    test('enum has all values', () {
      expect(PermissionLevel.values.length, 4);
      expect(PermissionLevel.read.name, 'read');
      expect(PermissionLevel.write.name, 'write');
      expect(PermissionLevel.admin.name, 'admin');
      expect(PermissionLevel.superAdmin.name, 'superAdmin');
    });
  });

  group('AdminUser', () {
    test('fromJson creates AdminUser from JSON', () {
      final json = {
        'id': 'a1',
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
        'status': 'active',
        'lastLogin': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      };

      final user = AdminUser.fromJson(json);
      expect(user.id, 'a1');
      expect(user.name, 'Admin User');
      expect(user.email, 'admin@example.com');
      expect(user.role, AdminRole.admin);
      expect(user.status, AdminUserStatus.active);
      expect(user.lastLogin, now);
    });

    test('toJson serializes correctly', () {
      final user = AdminUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@example.com',
        role: AdminRole.superAdmin,
        status: AdminUserStatus.active,
        createdAt: now,
      );

      final json = user.toJson();
      expect(json['id'], 'a1');
      expect(json['role'], 'superAdmin');
      expect(json['status'], 'active');
      expect(json['lastLogin'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@example.com',
        role: AdminRole.admin,
        status: AdminUserStatus.suspended,
        lastLogin: now,
        createdAt: now,
      );

      final restored = AdminUser.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = AdminUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@example.com',
        role: AdminRole.admin,
        status: AdminUserStatus.active,
        createdAt: now,
      );
      final b = AdminUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@example.com',
        role: AdminRole.admin,
        status: AdminUserStatus.active,
        createdAt: now,
      );
      final c = AdminUser(
        id: 'a2',
        name: 'Other',
        email: 'other@example.com',
        role: AdminRole.moderator,
        status: AdminUserStatus.pending,
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final user = AdminUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@example.com',
        role: AdminRole.admin,
        status: AdminUserStatus.active,
        createdAt: now,
      );

      final updated = user.copyWith(
        name: 'Super Admin',
        role: AdminRole.superAdmin,
      );
      expect(updated.name, 'Super Admin');
      expect(updated.role, AdminRole.superAdmin);
      expect(updated.id, 'a1');
      expect(user.name, 'Admin');
    });
  });

  group('AdminDashboard', () {
    test('fromJson creates AdminDashboard from JSON', () {
      final json = {
        'totalUsers': 1000,
        'totalMerchants': 50,
        'totalOrders': 5000,
        'totalRevenue': 100000.0,
        'activeDrivers': 30,
        'pendingOrders': 25,
      };

      final dashboard = AdminDashboard.fromJson(json);
      expect(dashboard.totalUsers, 1000);
      expect(dashboard.totalMerchants, 50);
      expect(dashboard.totalOrders, 5000);
      expect(dashboard.totalRevenue, 100000.0);
      expect(dashboard.activeDrivers, 30);
      expect(dashboard.pendingOrders, 25);
    });

    test('toJson serializes correctly', () {
      final dashboard = AdminDashboard(
        totalUsers: 1000,
        totalMerchants: 50,
        totalOrders: 5000,
        totalRevenue: 100000.0,
        activeDrivers: 30,
        pendingOrders: 25,
      );

      final json = dashboard.toJson();
      expect(json['totalUsers'], 1000);
      expect(json['totalRevenue'], 100000.0);
      expect(json['activeDrivers'], 30);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminDashboard(
        totalUsers: 1000,
        totalMerchants: 50,
        totalOrders: 5000,
        totalRevenue: 100000.0,
        activeDrivers: 30,
        pendingOrders: 25,
      );

      final restored = AdminDashboard.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = AdminDashboard(
        totalUsers: 1000,
        totalMerchants: 50,
        totalOrders: 5000,
        totalRevenue: 100000.0,
        activeDrivers: 30,
        pendingOrders: 25,
      );
      final b = AdminDashboard(
        totalUsers: 1000,
        totalMerchants: 50,
        totalOrders: 5000,
        totalRevenue: 100000.0,
        activeDrivers: 30,
        pendingOrders: 25,
      );

      expect(a, equals(b));
    });
  });

  group('AdminActivityLog', () {
    test('fromJson creates AdminActivityLog from JSON', () {
      final json = {
        'id': 'log1',
        'userId': 'a1',
        'action': 'suspend_user',
        'resource': 'users',
        'timestamp': now.toIso8601String(),
        'details': 'Suspended user u1',
      };

      final log = AdminActivityLog.fromJson(json);
      expect(log.id, 'log1');
      expect(log.userId, 'a1');
      expect(log.action, 'suspend_user');
      expect(log.resource, 'users');
      expect(log.details, 'Suspended user u1');
    });

    test('toJson serializes correctly', () {
      final log = AdminActivityLog(
        id: 'log1',
        userId: 'a1',
        action: 'login',
        resource: 'auth',
        timestamp: now,
      );

      final json = log.toJson();
      expect(json['id'], 'log1');
      expect(json['action'], 'login');
      expect(json['details'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminActivityLog(
        id: 'log1',
        userId: 'a1',
        action: 'delete_merchant',
        resource: 'merchants',
        timestamp: now,
        details: 'Deleted merchant m1',
      );

      final restored = AdminActivityLog.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('AdminPermission', () {
    test('fromJson creates AdminPermission from JSON', () {
      final json = {
        'id': 'perm1',
        'name': 'manage_users',
        'description': 'Can manage users',
        'module': 'users',
        'level': 'admin',
      };

      final perm = AdminPermission.fromJson(json);
      expect(perm.id, 'perm1');
      expect(perm.name, 'manage_users');
      expect(perm.description, 'Can manage users');
      expect(perm.module, 'users');
      expect(perm.level, PermissionLevel.admin);
    });

    test('toJson serializes correctly', () {
      final perm = AdminPermission(
        id: 'perm1',
        name: 'read_orders',
        description: 'Can read orders',
        module: 'orders',
        level: PermissionLevel.read,
      );

      final json = perm.toJson();
      expect(json['name'], 'read_orders');
      expect(json['level'], 'read');
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminPermission(
        id: 'perm1',
        name: 'write_products',
        description: 'Can write products',
        module: 'products',
        level: PermissionLevel.write,
      );

      final restored = AdminPermission.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('DriverModel', () {
    test('fromJson creates DriverModel from JSON', () {
      final json = {
        'id': 'd1',
        'userId': 'u1',
        'fullName': 'Driver One',
        'phone': '+20123456789',
        'vehicleType': 'Toyota',
        'vehiclePlate': 'ABC 123',
        'isAvailable': true,
        'isActive': true,
        'isVerified': true,
        'rating': 4.8,
        'totalTrips': 500,
        'lastLocationLat': 30.0444,
        'lastLocationLng': 31.2357,
        'createdAt': now.toIso8601String(),
      };

      final driver = DriverModel.fromJson(json);
      expect(driver.id, 'd1');
      expect(driver.userId, 'u1');
      expect(driver.fullName, 'Driver One');
      expect(driver.phone, '+20123456789');
      expect(driver.vehicleType, 'Toyota');
      expect(driver.vehiclePlate, 'ABC 123');
      expect(driver.isAvailable, true);
      expect(driver.isActive, true);
      expect(driver.isVerified, true);
      expect(driver.rating, 4.8);
      expect(driver.totalTrips, 500);
      expect(driver.lastLocationLat, 30.0444);
      expect(driver.lastLocationLng, 31.2357);
    });

    test('toJson serializes correctly', () {
      final driver = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        createdAt: now,
      );

      final json = driver.toJson();
      expect(json['id'], 'd1');
      expect(json['isAvailable'], false);
      expect(json['isActive'], false);
      expect(json['isVerified'], false);
      expect(json['rating'], 0.0);
      expect(json['totalTrips'], 0);
    });

    test('fromJson roundtrip preserves data', () {
      final original = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        phone: '+20123456789',
        vehicleType: 'Toyota',
        vehiclePlate: 'ABC 123',
        isAvailable: true,
        isActive: true,
        isVerified: true,
        rating: 4.8,
        totalTrips: 500,
        lastLocationLat: 30.0444,
        lastLocationLng: 31.2357,
        createdAt: now,
      );

      final restored = DriverModel.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        createdAt: now,
      );
      final b = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        createdAt: now,
      );
      final c = DriverModel(
        id: 'd2',
        userId: 'u2',
        fullName: 'Other Driver',
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final driver = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        createdAt: now,
      );

      final updated = driver.copyWith(
        fullName: 'Updated Driver',
        isAvailable: true,
        rating: 4.5,
      );
      expect(updated.fullName, 'Updated Driver');
      expect(updated.isAvailable, true);
      expect(updated.rating, 4.5);
      expect(updated.id, 'd1');
      expect(driver.fullName, 'Driver One');
    });

    test('defaults are applied correctly', () {
      final driver = DriverModel(
        id: 'd1',
        userId: 'u1',
        fullName: 'Driver One',
        createdAt: now,
      );

      expect(driver.isAvailable, false);
      expect(driver.isActive, false);
      expect(driver.isVerified, false);
      expect(driver.rating, 0.0);
      expect(driver.totalTrips, 0);
      expect(driver.phone, isNull);
      expect(driver.vehicleType, isNull);
      expect(driver.vehiclePlate, isNull);
      expect(driver.lastLocationLat, isNull);
      expect(driver.lastLocationLng, isNull);
    });
  });

  group('RideModel', () {
    test('fromJson creates RideModel from JSON', () {
      final json = {
        'id': 'rm1',
        'userId': 'u1',
        'driverId': 'd1',
        'serviceType': 'ride',
        'status': 'completed',
        'pickupLatitude': 30.0444,
        'pickupLongitude': 31.2357,
        'dropoffLatitude': 30.0131,
        'dropoffLongitude': 31.2089,
        'fare': 50.0,
        'distanceKm': 12.5,
        'durationMinutes': 25,
        'isScheduled': false,
        'scheduledTime': null,
        'paymentMethod': 'cash',
        'createdAt': now.toIso8601String(),
        'completedAt': null,
      };

      final ride = RideModel.fromJson(json);
      expect(ride.id, 'rm1');
      expect(ride.userId, 'u1');
      expect(ride.driverId, 'd1');
      expect(ride.serviceType, 'ride');
      expect(ride.status, 'completed');
      expect(ride.pickupLatitude, 30.0444);
      expect(ride.pickupLongitude, 31.2357);
      expect(ride.fare, 50.0);
      expect(ride.distanceKm, 12.5);
      expect(ride.durationMinutes, 25);
    });

    test('toJson serializes correctly', () {
      final ride = RideModel(
        id: 'rm1',
        status: 'pending',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        createdAt: now,
      );

      final json = ride.toJson();
      expect(json['id'], 'rm1');
      expect(json['serviceType'], 'ride');
      expect(json['isScheduled'], false);
      expect(json['paymentMethod'], 'cash');
    });

    test('fromJson roundtrip preserves data', () {
      final original = RideModel(
        id: 'rm1',
        userId: 'u1',
        driverId: 'd1',
        serviceType: 'delivery',
        status: 'in_progress',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        fare: 75.0,
        distanceKm: 20.0,
        durationMinutes: 35,
        isScheduled: true,
        scheduledTime: now,
        paymentMethod: 'card',
        createdAt: now,
      );

      final restored = RideModel.fromJson(original.toJson());
      expect(restored, original);
    });

    test('copyWith creates modified copy', () {
      final ride = RideModel(
        id: 'rm1',
        status: 'pending',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        createdAt: now,
      );

      final updated = ride.copyWith(
        status: 'completed',
        fare: 60.0,
        driverId: 'd1',
      );
      expect(updated.status, 'completed');
      expect(updated.fare, 60.0);
      expect(updated.driverId, 'd1');
      expect(ride.status, 'pending');
    });

    test('defaults are applied correctly', () {
      final ride = RideModel(
        id: 'rm1',
        status: 'pending',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        createdAt: now,
      );

      expect(ride.serviceType, 'ride');
      expect(ride.isScheduled, false);
      expect(ride.paymentMethod, 'cash');
      expect(ride.userId, isNull);
      expect(ride.driverId, isNull);
      expect(ride.fare, isNull);
      expect(ride.distanceKm, isNull);
      expect(ride.durationMinutes, isNull);
      expect(ride.scheduledTime, isNull);
    });
  });

  group('DeliveryModel', () {
    test('fromJson creates DeliveryModel from JSON', () {
      final json = {
        'id': 'del1',
        'userId': 'u1',
        'driverId': 'd1',
        'serviceType': 'delivery',
        'status': 'completed',
        'senderName': 'Sender',
        'senderPhone': '+20123456789',
        'receiverName': 'Receiver',
        'receiverPhone': '+20987654321',
        'itemDescription': 'Package',
        'itemWeight': 5.0,
        'itemUnit': 'kg',
        'totalPrice': 100.0,
        'pickupLatitude': 30.0444,
        'pickupLongitude': 31.2357,
        'dropoffLatitude': 30.0131,
        'dropoffLongitude': 31.2089,
        'createdAt': now.toIso8601String(),
      };

      final delivery = DeliveryModel.fromJson(json);
      expect(delivery.id, 'del1');
      expect(delivery.userId, 'u1');
      expect(delivery.driverId, 'd1');
      expect(delivery.serviceType, 'delivery');
      expect(delivery.status, 'completed');
      expect(delivery.senderName, 'Sender');
      expect(delivery.senderPhone, '+20123456789');
      expect(delivery.receiverName, 'Receiver');
      expect(delivery.receiverPhone, '+20987654321');
      expect(delivery.itemDescription, 'Package');
      expect(delivery.itemWeight, 5.0);
      expect(delivery.itemUnit, 'kg');
      expect(delivery.totalPrice, 100.0);
    });

    test('toJson serializes correctly', () {
      final delivery = DeliveryModel(
        id: 'del1',
        serviceType: 'delivery',
        status: 'pending',
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        createdAt: now,
      );

      final json = delivery.toJson();
      expect(json['id'], 'del1');
      expect(json['serviceType'], 'delivery');
      expect(json['senderName'], isNull);
      expect(json['totalPrice'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = DeliveryModel(
        id: 'del1',
        userId: 'u1',
        driverId: 'd1',
        serviceType: 'express',
        status: 'in_transit',
        senderName: 'Sender',
        senderPhone: '+20123456789',
        receiverName: 'Receiver',
        receiverPhone: '+20987654321',
        itemDescription: 'Document',
        itemWeight: 1.0,
        itemUnit: 'kg',
        totalPrice: 50.0,
        pickupLatitude: 30.0444,
        pickupLongitude: 31.2357,
        dropoffLatitude: 30.0131,
        dropoffLongitude: 31.2089,
        createdAt: now,
      );

      final restored = DeliveryModel.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('AdminDashboardMetrics', () {
    test('fromJson creates AdminDashboardMetrics from JSON', () {
      final json = {
        'totalUsers': 1000,
        'totalDrivers': 100,
        'totalMerchants': 50,
        'activeDrivers': 30,
        'pendingVerifications': 10,
        'totalRides': 5000,
        'activeRides': 15,
        'totalDeliveries': 2000,
        'pendingOrders': 25,
        'completedDeliveries': 1975,
        'totalRevenue': 100000.0,
        'revenueToday': 5000.0,
        'revenueThisMonth': 80000.0,
        'newUsersToday': 20,
        'newUsersThisMonth': 300,
      };

      final metrics = AdminDashboardMetrics.fromJson(json);
      expect(metrics.totalUsers, 1000);
      expect(metrics.totalDrivers, 100);
      expect(metrics.totalMerchants, 50);
      expect(metrics.activeDrivers, 30);
      expect(metrics.pendingVerifications, 10);
      expect(metrics.totalRides, 5000);
      expect(metrics.activeRides, 15);
      expect(metrics.totalDeliveries, 2000);
      expect(metrics.pendingOrders, 25);
      expect(metrics.completedDeliveries, 1975);
      expect(metrics.totalRevenue, 100000.0);
      expect(metrics.revenueToday, 5000.0);
      expect(metrics.revenueThisMonth, 80000.0);
      expect(metrics.newUsersToday, 20);
      expect(metrics.newUsersThisMonth, 300);
    });

    test('toJson serializes correctly', () {
      final metrics = AdminDashboardMetrics(
        totalUsers: 500,
        totalRevenue: 50000.0,
      );

      final json = metrics.toJson();
      expect(json['totalUsers'], 500);
      expect(json['totalRevenue'], 50000.0);
      expect(json['totalDrivers'], 0);
      expect(json['activeDrivers'], 0);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminDashboardMetrics(
        totalUsers: 1000,
        totalDrivers: 100,
        totalMerchants: 50,
        activeDrivers: 30,
        pendingVerifications: 10,
        totalRides: 5000,
        activeRides: 15,
        totalDeliveries: 2000,
        pendingOrders: 25,
        completedDeliveries: 1975,
        totalRevenue: 100000.0,
        revenueToday: 5000.0,
        revenueThisMonth: 80000.0,
        newUsersToday: 20,
        newUsersThisMonth: 300,
      );

      final restored = AdminDashboardMetrics.fromJson(original.toJson());
      expect(restored, original);
    });

    test('defaults are applied correctly', () {
      final metrics = AdminDashboardMetrics();

      expect(metrics.totalUsers, 0);
      expect(metrics.totalDrivers, 0);
      expect(metrics.totalMerchants, 0);
      expect(metrics.activeDrivers, 0);
      expect(metrics.pendingVerifications, 0);
      expect(metrics.totalRides, 0);
      expect(metrics.activeRides, 0);
      expect(metrics.totalDeliveries, 0);
      expect(metrics.pendingOrders, 0);
      expect(metrics.completedDeliveries, 0);
      expect(metrics.totalRevenue, 0.0);
      expect(metrics.revenueToday, 0.0);
      expect(metrics.revenueThisMonth, 0.0);
      expect(metrics.newUsersToday, 0);
      expect(metrics.newUsersThisMonth, 0);
    });

    test('equality works correctly', () {
      final a = AdminDashboardMetrics(totalUsers: 100, totalRevenue: 5000.0);
      final b = AdminDashboardMetrics(totalUsers: 100, totalRevenue: 5000.0);
      final c = AdminDashboardMetrics(totalUsers: 200, totalRevenue: 10000.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('AdminQuickAction', () {
    test('fromJson creates AdminQuickAction from JSON', () {
      final json = {
        'title': 'Manage Users',
        'icon': 'people',
        'route': '/admin/users',
        'subtitle': 'View all users',
      };

      final action = AdminQuickAction.fromJson(json);
      expect(action.title, 'Manage Users');
      expect(action.icon, 'people');
      expect(action.route, '/admin/users');
      expect(action.subtitle, 'View all users');
    });

    test('toJson serializes correctly', () {
      final action = AdminQuickAction(
        title: 'Dashboard',
        icon: 'dashboard',
        route: '/admin',
      );

      final json = action.toJson();
      expect(json['title'], 'Dashboard');
      expect(json['subtitle'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminQuickAction(
        title: 'Orders',
        icon: 'receipt',
        route: '/admin/orders',
        subtitle: 'Pending orders',
      );

      final restored = AdminQuickAction.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('RevenueData', () {
    test('fromJson creates RevenueData from JSON', () {
      final json = {
        'date': now.toIso8601String(),
        'amount': 5000.0,
      };

      final data = RevenueData.fromJson(json);
      expect(data.date, now);
      expect(data.amount, 5000.0);
    });

    test('toJson serializes correctly', () {
      final data = RevenueData(date: now, amount: 3000.0);

      final json = data.toJson();
      expect(json['amount'], 3000.0);
    });

    test('fromJson roundtrip preserves data', () {
      final original = RevenueData(date: now, amount: 7500.0);

      final restored = RevenueData.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = RevenueData(date: now, amount: 1000.0);
      final b = RevenueData(date: now, amount: 1000.0);
      final c = RevenueData(date: now, amount: 2000.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('AdminException', () {
    test('stores message correctly', () {
      const exception = AdminException('Something went wrong');
      expect(exception.message, 'Something went wrong');
    });

    test('toString returns correct format', () {
      const exception = AdminException('Test error');
      expect(exception.toString(), 'AdminException: Test error');
    });
  });
}
