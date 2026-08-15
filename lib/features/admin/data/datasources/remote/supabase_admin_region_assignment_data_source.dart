import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';

abstract class AdminRegionAssignmentDataSource {
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

class SupabaseAdminRegionAssignmentDataSource
    implements AdminRegionAssignmentDataSource {
  SupabaseAdminRegionAssignmentDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AdminRegionAssignment>> getAssignments({String? adminId}) async {
    try {
      var query = _client.from('admin_region_assignments').select();
      if (adminId != null) {
        query = query.eq('admin_id', adminId);
      }
      final rows = await query.order('created_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_fromRow)
          .toList();
    } catch (e) {
      throw AdminException('Failed to load region assignments: $e');
    }
  }

  @override
  Future<void> upsertAssignment({
    required String adminId,
    required String regionId,
    required AdminRegionScope scope,
  }) async {
    try {
      await _client.from('admin_region_assignments').upsert({
        'admin_id': adminId,
        'region_id': regionId,
        'scope': scope.code,
      }, onConflict: 'admin_id,region_id');
    } catch (e) {
      throw AdminException('Failed to save region assignment: $e');
    }
  }

  @override
  Future<void> deleteAssignment({
    required String adminId,
    required String regionId,
  }) async {
    try {
      await _client
          .from('admin_region_assignments')
          .delete()
          .eq('admin_id', adminId)
          .eq('region_id', regionId);
    } catch (e) {
      throw AdminException('Failed to delete region assignment: $e');
    }
  }

  AdminRegionAssignment _fromRow(Map<String, dynamic> row) {
    return AdminRegionAssignment(
      adminId: row['admin_id'] as String,
      regionId: row['region_id'] as String,
      scope: AdminRegionScope.fromCode(row['scope'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String),
      createdBy: row['created_by'] as String?,
    );
  }
}
