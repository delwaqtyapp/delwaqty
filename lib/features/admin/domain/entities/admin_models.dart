import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:delwaqty/domain/enums/user_type.dart';

part 'admin_models.freezed.dart';
part 'admin_models.g.dart';

// ─── Enums ─────────────────────────────────────────────────

enum AdminRole {
  owner,
  countryAdmin,
  governorateAdmin,
  centerAdmin,
  villageAdmin,
  admin;

  static AdminRole fromDb(String? value) => switch (value) {
    'super_admin' => AdminRole.owner,
    'country_admin' => AdminRole.countryAdmin,
    'governorate_admin' => AdminRole.governorateAdmin,
    'center_admin' => AdminRole.centerAdmin,
    'village_admin' => AdminRole.villageAdmin,
    _ => AdminRole.admin,
  };

  String toDb() => switch (this) {
    AdminRole.owner => 'super_admin',
    AdminRole.countryAdmin => 'country_admin',
    AdminRole.governorateAdmin => 'governorate_admin',
    AdminRole.centerAdmin => 'center_admin',
    AdminRole.villageAdmin => 'village_admin',
    AdminRole.admin => 'admin',
  };

  int get hierarchyLevel => switch (this) {
    AdminRole.owner => 0,
    AdminRole.countryAdmin => 1,
    AdminRole.governorateAdmin => 2,
    AdminRole.centerAdmin => 3,
    AdminRole.villageAdmin => 4,
    AdminRole.admin => 5,
  };

  bool canAssignRole(AdminRole target) => hierarchyLevel < target.hierarchyLevel;
}

enum AdminUserStatus { active, suspended, pending, deactivated }

enum PermissionLevel { read, write, admin, superAdmin }

// ─── Admin User ────────────────────────────────────────────

@freezed
abstract class AdminUser with _$AdminUser {
  const factory AdminUser({
    required String id,
    required String name,
    required String email,
    required AdminRole role,
    required AdminUserStatus status,
    DateTime? lastLogin,
    required DateTime createdAt,
  }) = _AdminUser;

  factory AdminUser.fromJson(Map<String, dynamic> json) =>
      _$AdminUserFromJson(json);
}

// ─── Admin Activity Log ────────────────────────────────────

@freezed
abstract class AdminActivityLog with _$AdminActivityLog {
  const factory AdminActivityLog({
    required String id,
    required String userId,
    required String action,
    required String resource,
    required DateTime timestamp,
    String? details,
  }) = _AdminActivityLog;

  factory AdminActivityLog.fromJson(Map<String, dynamic> json) =>
      _$AdminActivityLogFromJson(json);
}

// ─── Admin Permission ──────────────────────────────────────

@freezed
abstract class AdminPermission with _$AdminPermission {
  const factory AdminPermission({
    required String id,
    required String name,
    required String description,
    required String module,
    required PermissionLevel level,
  }) = _AdminPermission;

  factory AdminPermission.fromJson(Map<String, dynamic> json) =>
      _$AdminPermissionFromJson(json);
}

// ─── Driver Model ──────────────────────────────────────────

@freezed
abstract class DriverModel with _$DriverModel {
  const factory DriverModel({
    required String id,
    required String userId,
    required String fullName,
    String? phone,
    String? vehicleType,
    String? vehiclePlate,
    @Default(false) bool isAvailable,
    @Default(false) bool isActive,
    @Default(false) bool isVerified,
    @Default(0.0) double rating,
    @Default(0) int totalTrips,
    double? lastLocationLat,
    double? lastLocationLng,
    required DateTime createdAt,
  }) = _DriverModel;

  factory DriverModel.fromJson(Map<String, dynamic> json) =>
      _$DriverModelFromJson(json);
}

// ─── Delivery Model ────────────────────────────────────────
// Deliveries use the rides table with service_type != 'ride'

@freezed
abstract class DeliveryModel with _$DeliveryModel {
  const factory DeliveryModel({
    required String id,
    String? userId,
    String? driverId,
    required String serviceType,
    required String status,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
    String? itemDescription,
    double? itemWeight,
    String? itemUnit,
    double? totalPrice,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required DateTime createdAt,
  }) = _DeliveryModel;

  factory DeliveryModel.fromJson(Map<String, dynamic> json) =>
      _$DeliveryModelFromJson(json);
}

// ─── Admin Dashboard Metrics ───────────────────────────────

@freezed
abstract class AdminDashboardMetrics with _$AdminDashboardMetrics {
  const factory AdminDashboardMetrics({
    @Default(0) int totalUsers,
    @Default(0) int totalDrivers,
    @Default(0) int totalMerchants,
    @Default(0) int activeDrivers,
    @Default(0) int pendingVerifications,
    @Default(0) int totalRides,
    @Default(0) int activeRides,
    @Default(0) int totalDeliveries,
    @Default(0) int pendingOrders,
    @Default(0) int completedDeliveries,
    @Default(0.0) double totalRevenue,
    @Default(0.0) double revenueToday,
    @Default(0.0) double revenueThisMonth,
    @Default(0) int newUsersToday,
    @Default(0) int newUsersThisMonth,
  }) = _AdminDashboardMetrics;

  factory AdminDashboardMetrics.fromJson(Map<String, dynamic> json) =>
      _$AdminDashboardMetricsFromJson(json);
}

// ─── Admin Quick Action ────────────────────────────────────

@freezed
abstract class AdminQuickAction with _$AdminQuickAction {
  const factory AdminQuickAction({
    required String title,
    required String icon,
    required String route,
    String? subtitle,
  }) = _AdminQuickAction;

  factory AdminQuickAction.fromJson(Map<String, dynamic> json) =>
      _$AdminQuickActionFromJson(json);
}

// ─── Revenue Data ──────────────────────────────────────────

@freezed
abstract class RevenueData with _$RevenueData {
  const factory RevenueData({
    required DateTime date,
    required double amount,
  }) = _RevenueData;

  factory RevenueData.fromJson(Map<String, dynamic> json) =>
      _$RevenueDataFromJson(json);
}

// ─── Verification Request ──────────────────────────────────

@freezed
abstract class VerificationRequest with _$VerificationRequest {
  const factory VerificationRequest({
    required String userId,
    required String email,
    String? fullName,
    String? phone,
    required UserType userType,
    String? idCardUrl,
    String? profilePhotoUrl,
    required DateTime createdAt,
  }) = _VerificationRequest;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$VerificationRequestFromJson(json);
}

// ─── Exception ─────────────────────────────────────────────

class AdminException implements Exception {
  const AdminException(this.message);
  final String message;

  @override
  String toString() => 'AdminException: $message';
}
