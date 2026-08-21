import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/admin/escalation/domain/entities/escalation_event.dart';
import 'package:delwaqty/features/admin/escalation/domain/repositories/escalation_repository.dart';
import 'package:delwaqty/features/admin/escalation/data/datasources/remote/supabase_escalation_data_source.dart';
import 'package:delwaqty/features/admin/escalation/data/repositories/escalation_repository_impl.dart';

final supabaseEscalationDataSourceProvider =
    Provider<SupabaseEscalationDataSource>((ref) {
      return SupabaseEscalationDataSource(Supabase.instance.client);
    });

final escalationRepositoryProvider = Provider<EscalationRepository>((ref) {
  return EscalationRepositoryImpl(
    ref.read(supabaseEscalationDataSourceProvider),
  );
});

final escalationEventsProvider = FutureProvider<List<EscalationEvent>>((
  ref,
) async {
  final repo = ref.read(escalationRepositoryProvider);
  return repo.getEscalationEvents();
});

final escalateComplaintProvider =
    Provider<
      Future<void> Function({
        required String complaintId,
        required String reason,
      })
    >((ref) {
      return ({required String complaintId, required String reason}) async {
        await ref
            .read(escalationRepositoryProvider)
            .escalateComplaint(complaintId: complaintId, reason: reason);
        ref.invalidate(escalationEventsProvider);
      };
    });

final assignComplaintProvider =
    Provider<
      Future<void> Function({
        required String complaintId,
        required String adminId,
      })
    >((ref) {
      return ({required String complaintId, required String adminId}) async {
        await ref
            .read(escalationRepositoryProvider)
            .assignComplaint(complaintId: complaintId, adminId: adminId);
        ref.invalidate(escalationEventsProvider);
      };
    });
