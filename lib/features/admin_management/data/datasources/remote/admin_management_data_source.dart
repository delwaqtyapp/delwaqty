import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/admin_account.dart';

/// Remote data source for the Modern Admin Management Center.
/// Talks only to the modern, authorized RPCs. Never touches admin_users.
class AdminManagementDataSource {
  AdminManagementDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminAccount>> fetchAdmins() async {
    final res = await _client.rpc('get_all_admins');
    if (res == null) return [];
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(AdminAccount.fromRpc).toList();
  }

  Future<Map<String, dynamic>> fetchPermissions(String adminId) async {
    final res = await _client.rpc(
      'get_admin_permissions',
      params: {'p_admin_id': adminId},
    );
    if (res == null) return {'authorized': false, 'grants': [], 'effective': []};
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<AdminAuditEntry>> fetchAuditHistory(String adminId) async {
    final res = await _client.rpc(
      'get_admin_audit_history',
      params: {'p_admin_id': adminId},
    );
    if (res == null) return [];
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map((e) {
      DateTime? ts;
      final t = e['timestamp'];
      if (t is String) ts = DateTime.tryParse(t);
      return AdminAuditEntry(
        id: (e['id'] as String?) ?? '',
        action: (e['action'] as String?) ?? '',
        resource: (e['resource'] as String?) ?? '',
        resourceId: e['resource_id'] as String?,
        details: e['details'] == null
            ? null
            : Map<String, dynamic>.from(e['details'] as Map),
        timestamp: ts,
      );
    }).toList();
  }

  Future<void> assignRole({
    required String adminId,
    required String role,
    String? reason,
  }) async {
    await _client.rpc(
      'assign_admin_role',
      params: {
        'p_admin_id': adminId,
        'p_new_role': role,
        if (reason != null) 'p_reason': reason,
      },
    );
  }

  Future<void> assignRegion({
    required String adminId,
    required String regionId,
    String scope = 'descendants',
  }) async {
    await _client.rpc(
      'assign_admin_region',
      params: {
        'p_admin_id': adminId,
        'p_region_id': regionId,
        'p_scope': scope,
      },
    );
  }

  Future<void> changeSupervisor({
    required String adminId,
    required String newSupervisorId,
    String? reason,
  }) async {
    await _client.rpc(
      'change_admin_supervisor',
      params: {
        'p_admin_id': adminId,
        'p_new_supervisor_id': newSupervisorId,
        if (reason != null) 'p_reason': reason,
      },
    );
  }

  Future<void> deactivate({required String adminId, String? reason}) async {
    await _client.rpc(
      'deactivate_admin',
      params: {
        'p_admin_id': adminId,
        if (reason != null) 'p_reason': reason,
      },
    );
  }

  Future<void> reactivate({required String adminId, String? reason}) async {
    await _client.rpc(
      'reactivate_admin',
      params: {
        'p_admin_id': adminId,
        if (reason != null) 'p_reason': reason,
      },
    );
  }

  Future<void> grantPermission({
    required String adminId,
    required String permission,
  }) async {
    await _client.rpc(
      'grant_admin_permission',
      params: {'p_admin_id': adminId, 'p_permission': permission},
    );
  }

  Future<void> revokePermission({
    required String adminId,
    required String permission,
  }) async {
    await _client.rpc(
      'revoke_admin_permission',
      params: {'p_admin_id': adminId, 'p_permission': permission},
    );
  }

  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String fullName,
    String? supervisorId,
    String? regionId,
    String scope = 'descendants',
  }) async {
    final res = await _client.functions.invoke(
      'create-admin',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        if (supervisorId != null) 'supervisor_id': supervisorId,
        if (regionId != null) 'region_id': regionId,
        'scope': scope,
      },
    );
    final data = res.data;
    if (data == null) return {};
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return {};
  }
}
