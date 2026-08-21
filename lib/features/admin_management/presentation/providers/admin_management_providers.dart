import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_account.dart';
import '../../domain/repositories/admin_management_repository.dart';
import '../../data/datasources/remote/admin_management_data_source.dart';
import '../../data/repositories/admin_management_repository_impl.dart';

final adminManagementDataSourceProvider =
    Provider<AdminManagementDataSource>((ref) => AdminManagementDataSource());

final adminManagementRepositoryProvider =
    Provider<AdminManagementRepository>((ref) {
  return AdminManagementRepositoryImpl(
    ref.watch(adminManagementDataSourceProvider),
  );
});

/// All admins (extended identity contract). Refresh to pick up changes.
final adminsListProvider =
    FutureProvider<List<AdminAccount>>((ref) async {
  return ref.watch(adminManagementRepositoryProvider).fetchAdmins();
});

/// Single admin resolved from the list by id.
final adminDetailProvider =
    FutureProvider.family<AdminAccount?, String>((ref, id) async {
  final list = await ref.watch(adminsListProvider.future);
  return list.where((a) => a.id == id).firstOrNull;
});

final adminPermissionsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(adminManagementRepositoryProvider).fetchPermissions(id);
});

final adminAuditProvider =
    FutureProvider.family<List<AdminAuditEntry>, String>((ref, id) async {
  return ref.watch(adminManagementRepositoryProvider).fetchAuditHistory(id);
});

/// Performs sensitive admin actions and invalidates affected state.
final adminActionProvider =
    AsyncNotifierProvider<AdminActionNotifier, void>(
  AdminActionNotifier.new,
);

class AdminActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _run(String id, Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(adminsListProvider);
      ref.invalidate(adminDetailProvider(id));
      ref.invalidate(adminPermissionsProvider(id));
      ref.invalidate(adminAuditProvider(id));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> assignRole({
    required String id,
    required String adminId,
    required String role,
    String? reason,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .assignRole(adminId: adminId, role: role, reason: reason));

  Future<void> assignRegion({
    required String id,
    required String adminId,
    required String regionId,
    String scope = 'descendants',
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .assignRegion(adminId: adminId, regionId: regionId, scope: scope));

  Future<void> changeSupervisor({
    required String id,
    required String adminId,
    required String newSupervisorId,
    String? reason,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .changeSupervisor(
            adminId: adminId,
            newSupervisorId: newSupervisorId,
            reason: reason,
          ));

  Future<void> deactivate({
    required String id,
    required String adminId,
    String? reason,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .deactivate(adminId: adminId, reason: reason));

  Future<void> reactivate({
    required String id,
    required String adminId,
    String? reason,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .reactivate(adminId: adminId, reason: reason));

  Future<void> grantPermission({
    required String id,
    required String adminId,
    required String permission,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .grantPermission(adminId: adminId, permission: permission));

  Future<void> revokePermission({
    required String id,
    required String adminId,
    required String permission,
  }) =>
      _run(id, () => ref
          .read(adminManagementRepositoryProvider)
          .revokePermission(adminId: adminId, permission: permission));
}
