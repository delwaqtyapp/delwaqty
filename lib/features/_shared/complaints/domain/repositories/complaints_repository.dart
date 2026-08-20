import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';

abstract class ComplaintsRepository {
  Future<List<Complaint>> getComplaints({String? status, String? type});
  Future<List<Complaint>> getMyComplaints(String userId);
  Future<Complaint> getComplaintById(String id);
  Future<Complaint> createComplaint(Complaint complaint);
  Future<Complaint> updateComplaintStatus(
    String id,
    String status, {
    String? resolutionNote,
  });
  Future<void> escalateComplaint({required String id, required String reason});
  Future<void> addAdminNote(String id, String note);
  Future<void> deleteComplaint(String id);
}
