import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/data/datasources/remote/supabase_admin_region_assignment_data_source.dart';
import 'package:delwaqty/features/admin/data/repositories/admin_region_assignment_repository_impl.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';
import 'package:delwaqty/features/admin/domain/repositories/admin_region_assignment_repository.dart';

final supabaseAdminRegionAssignmentDataSourceProvider = Provider<
  AdminRegionAssignmentDataSource
>((ref) {
  return SupabaseAdminRegionAssignmentDataSource(Supabase.instance.client);
});

final adminRegionAssignmentRepositoryProvider = Provider<
  AdminRegionAssignmentRepository
>((ref) {
  return AdminRegionAssignmentRepositoryImpl(
    ref.watch(supabaseAdminRegionAssignmentDataSourceProvider),
  );
});

final adminRegionAssignmentsProvider = FutureProvider.family<
  List<AdminRegionAssignment>,
  String?
>((ref, adminId) {
  return ref.watch(adminRegionAssignmentRepositoryProvider).getAssignments(
    adminId: adminId,
  );
});

final adminTierUsersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final rows = await Supabase.instance.client
        .from('users')
        .select('id,email,full_name,role')
        .inFilter('role', ['admin', 'owner'])
        .order('full_name');
    return (rows as List).cast<Map<String, dynamic>>();
  },
);

final upsertAdminRegionAssignmentProvider = Provider<
  Future<void> Function({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
  })
>((ref) {
  return ({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
  }) async {
    await ref
        .read(adminRegionAssignmentRepositoryProvider)
        .upsertAssignment(
          adminId: adminId,
          regionId: regionId,
          scope: scope,
        );
    ref.invalidate(adminRegionAssignmentsProvider(adminId));
  };
});

final deleteAdminRegionAssignmentProvider = Provider<
  Future<void> Function({required String adminId, required String regionId})
>((ref) {
  return ({required String adminId, required String regionId}) async {
    await ref
        .read(adminRegionAssignmentRepositoryProvider)
        .deleteAssignment(adminId: adminId, regionId: regionId);
    ref.invalidate(adminRegionAssignmentsProvider(adminId));
  };
});
