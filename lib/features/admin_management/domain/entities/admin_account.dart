import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_account.freezed.dart';
part 'admin_account.g.dart';

enum AdminScope { self, descendants, unknown }

/// Canonical permission vocabulary (mirrors _valid_permission in 034).
const List<String> adminPermissionVocabulary = [
  'ADMIN_CREATE',
  'ADMIN_ASSIGN',
  'ADMIN_ROLE_ASSIGN',
  'ADMIN_REGION_ASSIGN',
  'ADMIN_SUPERVISOR_ASSIGN',
  'ADMIN_SUSPEND',
  'MEMBER_VIEW',
  'MEMBER_VIEW_LOCATION',
  'MEMBER_VIEW_CHAT_HISTORY',
  'MEMBER_VIEW_COMPLAINTS',
  'MEMBER_VIEW_TIMELINE',
  'MEMBER_VIEW_DOCUMENTS',
  'MEMBER_MODERATE',
  'MEMBER_WARN',
  'MEMBER_RESTRICT',
  'MEMBER_SUSPEND',
  'MEMBER_BAN',
  'MEMBER_DELETE',
  'EMERGENCY_VIEW',
  'EMERGENCY_AUDIO',
  'OFFER_CREATE',
  'OFFER_REVIEW',
  'OFFER_APPROVE',
  'OFFER_PUBLISH',
];

/// Canonical admin identity sourced from the modern contract
/// (users + admin_management + admin_region_assignments).
/// Never uses the legacy admin_users table.
@freezed
abstract class AdminAccount with _$AdminAccount {
  const factory AdminAccount({
    required String id,
    required String email,
    String? fullName,
    required String role,
    @Default(true) bool isActive,
    String? regionId,
    String? regionName,
    @Default(AdminScope.unknown) AdminScope scope,
    String? supervisorId,
    String? supervisorEmail,
    DateTime? createdAt,
    @Default([]) List<String> permissions,
  }) = _AdminAccount;

  factory AdminAccount.fromJson(Map<String, dynamic> json) =>
      _$AdminAccountFromJson(json);

  /// Parses the row returned by the extended get_all_admins() RPC.
  factory AdminAccount.fromRpc(Map<String, dynamic> json) {
    final scopeRaw = json['scope'] as String?;
    final scope = scopeRaw == 'self'
        ? AdminScope.self
        : scopeRaw == 'descendants'
            ? AdminScope.descendants
            : AdminScope.unknown;
    DateTime? createdAt;
    final c = json['created_at'];
    if (c is String) createdAt = DateTime.tryParse(c);
    return AdminAccount(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      fullName: json['full_name'] as String?,
      role: (json['role'] as String?) ?? 'admin',
      isActive: (json['is_active'] as bool?) ?? true,
      regionId: json['region_id'] as String?,
      regionName: json['region_name'] as String?,
      scope: scope,
      supervisorId: json['supervisor_id'] as String?,
      supervisorEmail: json['supervisor_email'] as String?,
      createdAt: createdAt,
    );
  }
}

@freezed
abstract class AdminAuditEntry with _$AdminAuditEntry {
  const factory AdminAuditEntry({
    required String id,
    required String action,
    required String resource,
    String? resourceId,
    Map<String, dynamic>? details,
    DateTime? timestamp,
  }) = _AdminAuditEntry;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) =>
      _$AdminAuditEntryFromJson(json);
}
