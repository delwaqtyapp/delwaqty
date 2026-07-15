enum AdminRole { superAdmin, admin, moderator, support }

enum AdminUserStatus { active, suspended, pending, deactivated }

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.lastLogin,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final AdminRole role;
  final AdminUserStatus status;
  final DateTime? lastLogin;
  final DateTime createdAt;

  AdminUser copyWith({
    String? id,
    String? name,
    String? email,
    AdminRole? role,
    AdminUserStatus? status,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AdminDashboard {
  const AdminDashboard({
    required this.totalUsers,
    required this.totalMerchants,
    required this.totalOrders,
    required this.totalRevenue,
    required this.activeDrivers,
    required this.pendingOrders,
  });

  final int totalUsers;
  final int totalMerchants;
  final int totalOrders;
  final double totalRevenue;
  final int activeDrivers;
  final int pendingOrders;
}

class AdminActivityLog {
  const AdminActivityLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.resource,
    required this.timestamp,
    this.details,
  });

  final String id;
  final String userId;
  final String action;
  final String resource;
  final DateTime timestamp;
  final String? details;
}

class AdminPermission {
  const AdminPermission({
    required this.id,
    required this.name,
    required this.description,
    required this.module,
    required this.level,
  });

  final String id;
  final String name;
  final String description;
  final String module;
  final PermissionLevel level;
}

enum PermissionLevel { read, write, admin, superAdmin }
