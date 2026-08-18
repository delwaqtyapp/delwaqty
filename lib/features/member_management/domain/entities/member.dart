class Member {
  const Member({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.username,
    this.avatarUrl,
    this.role,
    this.userType,
    this.accountStatus,
    this.verificationStatus,
    this.regionId,
    this.regionLabel,
    this.lastSeenAt,
    this.isOnline,
    this.serviceTypes,
    this.serviceCategories,
    this.ordersCount,
    this.ridesCount,
    this.bookingsCount,
    this.walletBalance,
    this.walletCurrency,
    this.activeSanctionsCount,
    required this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String? ?? 'customer',
        userType: json['user_type'] as String?,
        accountStatus: json['account_status'] as String? ?? 'active',
        verificationStatus: json['verification_status'] as String? ?? 'unverified',
        regionId: json['region_id'] as String?,
        regionLabel: json['region_label'] as String?,
        lastSeenAt: json['last_seen_at'] != null ? DateTime.parse(json['last_seen_at'] as String) : null,
        isOnline: json['is_online'] as bool?,
        serviceTypes: (json['service_types'] as List<dynamic>?)
            ?.cast<String>(),
        serviceCategories: (json['service_categories'] as List<dynamic>?)
            ?.cast<String>(),
        ordersCount: (json['orders_count'] as num?)?.toInt(),
        ridesCount: (json['rides_count'] as num?)?.toInt(),
        bookingsCount: (json['bookings_count'] as num?)?.toInt(),
        walletBalance: json['wallet_balance'] as num?,
        walletCurrency: json['wallet_currency'] as String?,
        activeSanctionsCount: (json['active_sanctions_count'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? username;
  final String? avatarUrl;
  final String? role;
  final String? userType;
  final String? accountStatus;
  final String? verificationStatus;
  final String? regionId;
  final String? regionLabel;
  final DateTime? lastSeenAt;
  final bool? isOnline;
  final List<String>? serviceTypes;
  final List<String>? serviceCategories;
  final int? ordersCount;
  final int? ridesCount;
  final int? bookingsCount;
  final num? walletBalance;
  final String? walletCurrency;
  final int? activeSanctionsCount;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'username': username,
        'avatar_url': avatarUrl,
        'role': role,
        'user_type': userType,
        'account_status': accountStatus,
        'verification_status': verificationStatus,
        'region_id': regionId,
        'region_label': regionLabel,
        'last_seen_at': lastSeenAt?.toIso8601String(),
        'is_online': isOnline,
        'service_types': serviceTypes,
        'service_categories': serviceCategories,
        'orders_count': ordersCount,
        'rides_count': ridesCount,
        'bookings_count': bookingsCount,
        'wallet_balance': walletBalance,
        'wallet_currency': walletCurrency,
        'active_sanctions_count': activeSanctionsCount,
        'created_at': createdAt.toIso8601String(),
      };
}
