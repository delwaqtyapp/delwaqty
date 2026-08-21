import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/admin/escalation/domain/entities/escalation_event.dart';

class SupabaseEscalationDataSource {
  final SupabaseClient _client;

  SupabaseEscalationDataSource(this._client);

  Future<void> escalateComplaint({
    required String complaintId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'escalate_complaint',
        params: {'p_complaint_id': complaintId, 'p_reason': reason},
      );
    } catch (e) {
      throw ServerException(message: _rpcError(e));
    }
  }

  Future<void> assignComplaint({
    required String complaintId,
    required String adminId,
  }) async {
    try {
      await _client.rpc(
        'assign_complaint',
        params: {'p_complaint_id': complaintId, 'p_admin_id': adminId},
      );
    } catch (e) {
      throw ServerException(message: _rpcError(e));
    }
  }

  Future<List<EscalationEvent>> getEscalationEvents({
    String? complaintId,
  }) async {
    try {
      final result = await _client.rpc(
        'get_escalation_events',
        params: {if (complaintId != null) 'p_complaint_id': complaintId},
      );
      final rows = (result as List?) ?? const [];
      return rows
          .map(
            (r) =>
                EscalationEvent.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } catch (e) {
      throw ServerException(message: _rpcError(e));
    }
  }

  String _rpcError(Object error) {
    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.contains('Not authorized')) {
        return 'Not authorized';
      }
      if (msg.contains('Escalation requires a reason')) {
        return 'Escalation requires a reason';
      }
      if (msg.contains('Complaint is already closed')) {
        return 'Complaint is already closed';
      }
      if (msg.contains('Complaint not found')) {
        return 'Complaint not found';
      }
      if (msg.contains('Assignee must be an admin')) {
        return 'Assignee must be an admin';
      }
      if (msg.contains('must be in scope')) {
        return 'Assignee must be in scope for the complaint region';
      }
      return msg;
    }
    return error.toString();
  }
}
