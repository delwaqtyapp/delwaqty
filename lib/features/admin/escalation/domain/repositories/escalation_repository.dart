import 'package:delwaqty/features/admin/escalation/domain/entities/escalation_event.dart';

abstract class EscalationRepository {
  Future<void> escalateComplaint({
    required String complaintId,
    required String reason,
  });

  Future<void> assignComplaint({
    required String complaintId,
    required String adminId,
  });

  Future<List<EscalationEvent>> getEscalationEvents({String? complaintId});
}
