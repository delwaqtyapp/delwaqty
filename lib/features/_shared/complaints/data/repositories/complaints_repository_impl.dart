import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';
import 'package:delwaqty/features/_shared/complaints/domain/repositories/complaints_repository.dart';
import 'package:delwaqty/features/_shared/complaints/data/datasources/remote/supabase_complaints_data_source.dart';

class ComplaintsRepositoryImpl implements ComplaintsRepository {
  final SupabaseComplaintsDataSource _dataSource;

  ComplaintsRepositoryImpl(this._dataSource);

  @override
  Future<List<Complaint>> getComplaints({String? status, String? type}) {
    return _dataSource.getComplaints(status: status, type: type);
  }

  @override
  Future<List<Complaint>> getMyComplaints(String userId) {
    return _dataSource.getMyComplaints(userId);
  }

  @override
  Future<Complaint> getComplaintById(String id) {
    return _dataSource.getComplaintById(id);
  }

  @override
  Future<Complaint> createComplaint(Complaint complaint) {
    return _dataSource.createComplaint(complaint);
  }

  @override
  Future<Complaint> updateComplaintStatus(
    String id,
    String status, {
    String? resolutionNote,
  }) {
    return _dataSource.updateComplaintStatus(
      id,
      status,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<void> escalateComplaint({required String id, required String reason}) {
    return _dataSource.escalateComplaint(id: id, reason: reason);
  }

  @override
  Future<void> addAdminNote(String id, String note) {
    return _dataSource.addAdminNote(id, note);
  }

  @override
  Future<void> deleteComplaint(String id) {
    return _dataSource.deleteComplaint(id);
  }
}
