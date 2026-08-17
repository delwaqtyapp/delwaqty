import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/escalation/data/datasources/remote/supabase_escalation_data_source.dart';
import 'package:delwaqty/features/escalation/data/repositories/escalation_repository_impl.dart';
import 'package:delwaqty/features/escalation/domain/entities/escalation_event.dart';

class MockEscalationDataSource extends Mock
    implements SupabaseEscalationDataSource {}

void main() {
  late MockEscalationDataSource mockDataSource;
  late EscalationRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockEscalationDataSource();
    repository = EscalationRepositoryImpl(mockDataSource);
  });

  group('EscalationRepositoryImpl.escalateComplaint', () {
    test('delegates to data source with correct params', () async {
      when(() => mockDataSource.escalateComplaint(
            complaintId: any(named: 'complaintId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await repository.escalateComplaint(
        complaintId: 'complaint-1',
        reason: 'Understaffed',
      );

      verify(() => mockDataSource.escalateComplaint(
            complaintId: 'complaint-1',
            reason: 'Understaffed',
          )).called(1);
    });

    test('propagates ServerException from data source', () async {
      when(() => mockDataSource.escalateComplaint(
            complaintId: any(named: 'complaintId'),
            reason: any(named: 'reason'),
          )).thenThrow(const ServerException(message: 'Complaint not found'));

      expect(
        () => repository.escalateComplaint(
          complaintId: 'nonexistent',
          reason: 'Test',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('EscalationRepositoryImpl.assignComplaint', () {
    test('delegates to data source with correct params', () async {
      when(() => mockDataSource.assignComplaint(
            complaintId: any(named: 'complaintId'),
            adminId: any(named: 'adminId'),
          )).thenAnswer((_) async {});

      await repository.assignComplaint(
        complaintId: 'complaint-1',
        adminId: 'admin-1',
      );

      verify(() => mockDataSource.assignComplaint(
            complaintId: 'complaint-1',
            adminId: 'admin-1',
          )).called(1);
    });
  });

  group('EscalationRepositoryImpl.getEscalationEvents', () {
    test('returns events list from data source', () async {
      final events = [
        EscalationEvent(
          id: 'e1',
          entityType: 'complaint',
          entityId: 'complaint-1',
          actorId: 'admin-1',
          reason: 'Understaffed',
          newScope: 'scoped',
          createdAt: DateTime(2026, 8, 18),
        ),
      ];
      when(() => mockDataSource.getEscalationEvents(
            complaintId: any(named: 'complaintId'),
          )).thenAnswer((_) async => events);

      final result = await repository.getEscalationEvents(
        complaintId: 'complaint-1',
      );

      expect(result, events);
      verify(() => mockDataSource.getEscalationEvents(
            complaintId: 'complaint-1',
          )).called(1);
    });

    test('passes null complaintId when omitted', () async {
      when(() => mockDataSource.getEscalationEvents(
            complaintId: any(named: 'complaintId'),
          )).thenAnswer((_) async => []);

      await repository.getEscalationEvents();

      verify(() => mockDataSource.getEscalationEvents()).called(1);
    });
  });

  group('EscalationEvent', () {
    test('parses scoped escalation from JSON', () {
      final event = EscalationEvent.fromJson({
        'id': 'e1',
        'entity_type': 'complaint',
        'entity_id': 'complaint-1',
        'from_admin_id': 'admin-1',
        'to_admin_id': 'admin-2',
        'actor_id': 'admin-1',
        'reason': 'Understaffed',
        'previous_scope': 'unassigned',
        'new_scope': 'scoped',
        'created_at': '2026-08-18T10:00:00Z',
      });

      expect(event.id, 'e1');
      expect(event.fromAdminId, 'admin-1');
      expect(event.toAdminId, 'admin-2');
      expect(event.previousScope, 'unassigned');
      expect(event.newScope, 'scoped');
      expect(event.isOwnerQueue, isFalse);
    });

    test('marks owner queue events', () {
      final event = EscalationEvent.fromJson({
        'id': 'e2',
        'entity_id': 'complaint-1',
        'actor_id': 'admin-1',
        'reason': 'Out of scope',
        'new_scope': 'owner',
        'created_at': '2026-08-18T10:05:00Z',
      });

      expect(event.isOwnerQueue, isTrue);
      expect(event.newScope, 'owner');
    });
  });
}