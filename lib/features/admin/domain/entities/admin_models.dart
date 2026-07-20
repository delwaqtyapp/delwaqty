import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_models.freezed.dart';
part 'admin_models.g.dart';

// ─── Enums ─────────────────────────────────────────────────

enum AdminRole { superAdmin, admin, moderator, support }

enum AdminUserStatus { active, suspended, pending, deactivated }

enum PermissionLevel { read, write, admin, superAdmin }

// ─── Admin User ────────────────────────────────────────────

@freezed
class AdminUser with _$AdminUser {
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

// ─── Admin Dashboard (Legacy) ──────────────────────────────

@freezed
class AdminDashboard with _$AdminDashboard {
  const factory AdminDashboard({
    required int totalUsers,
    required int totalMerchants,
    required int totalOrders,
    required double totalRevenue,
    required int activeDrivers,
    required int pendingOrders,
  }) = _AdminDashboard;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) =>
      _$AdminDashboardFromJson(json);
}

// ─── Admin Activity Log ────────────────────────────────────

@freezed
class AdminActivityLog with _$AdminActivityLog {
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
class AdminPermission with _$AdminPermission {
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
class DriverModel with _$DriverModel {
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

// ─── Ride Model ────────────────────────────────────────────

@freezed
class RideModel with _$RideModel {
  const factory RideModel({
    required String id,
    String? userId,
    String? driverId,
    @Default('ride') String serviceType,
    required String status,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    double? fare,
    double? distanceKm,
    int? durationMinutes,
    @Default(false) bool isScheduled,
    DateTime? scheduledTime,
    @Default('cash') String paymentMethod,
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _RideModel;

  factory RideModel.fromJson(Map<String, dynamic> json) =>
      _$RideModelFromJson(json);
}

// ─── Delivery Model ────────────────────────────────────────
// Deliveries use the rides table with service_type != 'ride'

@freezed
class DeliveryModel with _$DeliveryModel {
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
class AdminDashboardMetrics with _$AdminDashboardMetrics {
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
class AdminQuickAction with _$AdminQuickAction {
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
class RevenueData with _$RevenueData {
  const factory RevenueData({
    required DateTime date,
    required double amount,
  }) = _RevenueData;

  factory RevenueData.fromJson(Map<String, dynamic> json) =>
      _$RevenueDataFromJson(json);
}

// ─── Exception ─────────────────────────────────────────────

class AdminException implements Exception {
  const AdminException(this.message);
  final String message;

  @override
  String toString() => 'AdminException: $message';
}
