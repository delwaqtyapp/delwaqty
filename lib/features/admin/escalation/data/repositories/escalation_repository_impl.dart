import 'package:delwaqty/features/admin/escalation/domain/entities/escalation_event.dart';
import 'package:delwaqty/features/admin/escalation/domain/repositories/escalation_repository.dart';
import 'package:delwaqty/features/admin/escalation/data/datasources/remote/supabase_escalation_data_source.dart';

class EscalationRepositoryImpl implements EscalationRepository {
  final SupabaseEscalationDataSource _dataSource;

  EscalationRepositoryImpl(this._dataSource);

  @override
  Future<void> escalateComplaint({
    required String complaintId,
    required String reason,
  }) {
    return _dataSource.escalateComplaint(
      complaintId: complaintId,
      reason: reason,
    );
  }

  @override
  Future<void> assignComplaint({
    required String complaintId,
    required String adminId,
  }) {
    return _dataSource.assignComplaint(
      complaintId: complaintId,
      adminId: adminId,
    );
  }

  @override
  Future<List<EscalationEvent>> getEscalationEvents({String? complaintId}) {
    return _dataSource.getEscalationEvents(complaintId: complaintId);
  }
}
