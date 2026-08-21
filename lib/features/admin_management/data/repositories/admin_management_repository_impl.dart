import '../../domain/entities/admin_account.dart';
import '../../domain/repositories/admin_management_repository.dart';
import '../datasources/remote/admin_management_data_source.dart';

class AdminManagementRepositoryImpl implements AdminManagementRepository {
  AdminManagementRepositoryImpl(this._dataSource);

  final AdminManagementDataSource _dataSource;

  @override
  Future<List<AdminAccount>> fetchAdmins() => _dataSource.fetchAdmins();

  @override
  Future<Map<String, dynamic>> fetchPermissions(String adminId) =>
      _dataSource.fetchPermissions(adminId);

  @override
  Future<List<AdminAuditEntry>> fetchAuditHistory(String adminId) =>
      _dataSource.fetchAuditHistory(adminId);

  @override
  Future<void> assignRole({
    required String adminId,
    required String role,
    String? reason,
  }) =>
      _dataSource.assignRole(adminId: adminId, role: role, reason: reason);

  @override
  Future<void> assignRegion({
    required String adminId,
    required String regionId,
    String scope = 'descendants',
  }) =>
      _dataSource.assignRegion(
        adminId: adminId,
        regionId: regionId,
        scope: scope,
      );

  @override
  Future<void> changeSupervisor({
    required String adminId,
    required String newSupervisorId,
    String? reason,
  }) =>
      _dataSource.changeSupervisor(
        adminId: adminId,
        newSupervisorId: newSupervisorId,
        reason: reason,
      );

  @override
  Future<void> deactivate({required String adminId, String? reason}) =>
      _dataSource.deactivate(adminId: adminId, reason: reason);

  @override
  Future<void> reactivate({required String adminId, String? reason}) =>
      _dataSource.reactivate(adminId: adminId, reason: reason);

  @override
  Future<void> grantPermission({
    required String adminId,
    required String permission,
  }) =>
      _dataSource.grantPermission(adminId: adminId, permission: permission);

  @override
  Future<void> revokePermission({
    required String adminId,
    required String permission,
  }) =>
      _dataSource.revokePermission(adminId: adminId, permission: permission);

  @override
  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String fullName,
    String? supervisorId,
    String? regionId,
    String scope = 'descendants',
  }) =>
      _dataSource.createAdmin(
        email: email,
        password: password,
        fullName: fullName,
        supervisorId: supervisorId,
        regionId: regionId,
        scope: scope,
      );
}
