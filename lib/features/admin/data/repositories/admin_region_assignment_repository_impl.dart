import 'package:delwaqty/features/admin/data/datasources/remote/supabase_admin_region_assignment_data_source.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';
import 'package:delwaqty/features/admin/domain/repositories/admin_region_assignment_repository.dart';

class AdminRegionAssignmentRepositoryImpl
    implements AdminRegionAssignmentRepository {
  AdminRegionAssignmentRepositoryImpl(this._dataSource);

  final AdminRegionAssignmentDataSource _dataSource;

  @override
  Future<List<AdminRegionAssignment>> getAssignments({String? adminId}) {
    return _dataSource.getAssignments(adminId: adminId);
  }

  @override
  Future<void> upsertAssignment({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
  }) {
    return _dataSource.upsertAssignment(
      adminId: adminId,
      regionId: regionId,
      scope: scope,
    );
  }

  @override
  Future<void> deleteAssignment({
    required String adminId,
    required String regionId,
  }) {
    return _dataSource.deleteAssignment(adminId: adminId, regionId: regionId);
  }
}
