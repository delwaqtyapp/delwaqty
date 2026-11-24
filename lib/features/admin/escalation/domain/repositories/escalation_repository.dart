import 'package:delwaqty/features/admin/escalation/domain/entities/escalation_event.dart';
import 'package:delwaqty/features/admin/escalation/domain/entities/tamper_alert.dart';

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

  Future<List<ClientPricedAlert>> getClientPricedAlerts();
}
