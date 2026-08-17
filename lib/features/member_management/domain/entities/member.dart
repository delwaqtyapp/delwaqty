class Member {
  const Member({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.accountStatus,
    required this.verificationStatus,
    this.regionId,
    required this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'customer',
        accountStatus: json['account_status'] as String? ?? 'active',
        verificationStatus: json['verification_status'] as String? ?? 'unverified',
        regionId: json['region_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String role;
  final String accountStatus;
  final String verificationStatus;
  final String? regionId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'account_status': accountStatus,
        'verification_status': verificationStatus,
        'region_id': regionId,
        'created_at': createdAt.toIso8601String(),
      };
}
