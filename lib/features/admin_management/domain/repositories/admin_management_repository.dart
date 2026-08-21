import '../entities/admin_account.dart';

/// Contract for the Modern Admin Management Center.
/// All operations are enforced server-side by the modern RPCs
/// (get_all_admins / get_admin_permissions / get_admin_audit_history /
/// assign_admin_role / assign_admin_region / change_admin_supervisor /
/// deactivate_admin / reactivate_admin / create-admin Edge Function).
abstract class AdminManagementRepository {
  Future<List<AdminAccount>> fetchAdmins();

  Future<Map<String, dynamic>> fetchPermissions(String adminId);

  Future<List<AdminAuditEntry>> fetchAuditHistory(String adminId);

  Future<void> assignRole({
    required String adminId,
    required String role,
    String? reason,
  });

  Future<void> assignRegion({
    required String adminId,
    required String regionId,
    String scope = 'descendants',
  });

  Future<void> changeSupervisor({
    required String adminId,
    required String newSupervisorId,
    String? reason,
  });

  Future<void> deactivate({required String adminId, String? reason});

  Future<void> reactivate({required String adminId, String? reason});

  Future<void> grantPermission({
    required String adminId,
    required String permission,
  });

  Future<void> revokePermission({
    required String adminId,
    required String permission,
  });

  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String fullName,
    String? supervisorId,
    String? regionId,
    String scope = 'descendants',
  });
}
