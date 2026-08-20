import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';

abstract class AdminRegionAssignmentRepository {
  Future<List<AdminRegionAssignment>> getAssignments({String? adminId});

  Future<void> upsertAssignment({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
  });

  Future<void> deleteAssignment({
    required String adminId,
    required String regionId,
  });
}
