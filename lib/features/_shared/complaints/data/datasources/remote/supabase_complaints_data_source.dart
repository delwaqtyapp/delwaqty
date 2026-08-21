import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';

class SupabaseComplaintsDataSource {
  final SupabaseClient _client;

  SupabaseComplaintsDataSource(this._client);

  Future<List<Complaint>> getComplaints({String? status, String? type}) async {
    var query = _client.from('complaints').select();
    if (status != null) query = query.eq('status', status);
    if (type != null) query = query.eq('complaint_type', type);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => Complaint.fromJson(r)).toList();
  }

  Future<List<Complaint>> getMyComplaints(String userId) async {
    final rows = await _client
        .from('complaints')
        .select()
        .eq('complainant_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => Complaint.fromJson(r)).toList();
  }

  Future<Complaint> getComplaintById(String id) async {
    final row = await _client.from('complaints').select().eq('id', id).single();
    return Complaint.fromJson(row);
  }

  Future<Complaint> createComplaint(Complaint complaint) async {
    final payload = Map<String, dynamic>.from(complaint.toJson());
    if (payload['id'] == null || (payload['id'] as String).isEmpty) {
      payload.remove('id');
    }
    final row = await _client
        .from('complaints')
        .insert(payload)
        .select()
        .single();
    return Complaint.fromJson(row);
  }

  Future<Complaint> updateComplaintStatus(
    String id,
    String status, {
    String? resolutionNote,
  }) async {
    if (status == 'escalated') {
      throw const ServerException(
        message: 'Escalated status must be set via escalate_complaint()',
      );
    }
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == 'resolved' || status == 'rejected') {
      updates['resolved_at'] = DateTime.now().toIso8601String();
    }
    if (resolutionNote != null) updates['resolution_note'] = resolutionNote;
    await _client.from('complaints').update(updates).eq('id', id);
    return getComplaintById(id);
  }

  Future<void> escalateComplaint({
    required String id,
    required String reason,
  }) async {
    await _client.rpc(
      'escalate_complaint',
      params: {'p_complaint_id': id, 'p_reason': reason},
    );
  }

  Future<void> addAdminNote(String id, String note) async {
    await _client.rpc(
      'add_complaint_admin_note',
      params: {'p_complaint_id': id, 'p_note': note},
    );
  }

  Future<void> deleteComplaint(String id) async {
    await _client.from('complaints').delete().eq('id', id);
  }
}
