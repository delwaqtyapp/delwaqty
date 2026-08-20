import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/admin/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart';
import 'package:delwaqty/features/admin/sanctions/data/repositories/sanctions_repository_impl.dart';
import 'package:delwaqty/features/admin/sanctions/domain/entities/sanction.dart';

class MockSanctionsDataSource extends Mock
    implements SupabaseSanctionsDataSource {}

void main() {
  late MockSanctionsDataSource mockDataSource;
  late SanctionsRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockSanctionsDataSource();
    repository = SanctionsRepositoryImpl(mockDataSource);
  });

  group('SanctionsRepositoryImpl.issueSanction', () {
    test('delegates to data source with correct params', () async {
      when(() => mockDataSource.issueSanction(
            memberId: any(named: 'memberId'),
            sanctionType: any(named: 'sanctionType'),
            reason: any(named: 'reason'),
            durationDays: any(named: 'durationDays'),
            amount: any(named: 'amount'),
            evidenceUrl: any(named: 'evidenceUrl'),
          )).thenAnswer((_) async => 'sanction-id-123');

      final result = await repository.issueSanction(
        memberId: 'member-1',
        sanctionType: 'warning',
        reason: 'Test warning',
      );

      expect(result, 'sanction-id-123');
      verify(() => mockDataSource.issueSanction(
            memberId: 'member-1',
            sanctionType: 'warning',
            reason: 'Test warning',
            durationDays: 0,
            amount: 0,
            evidenceUrl: null,
          )).called(1);
    });

    test('passes optional params correctly', () async {
      when(() => mockDataSource.issueSanction(
            memberId: any(named: 'memberId'),
            sanctionType: any(named: 'sanctionType'),
            reason: any(named: 'reason'),
            durationDays: any(named: 'durationDays'),
            amount: any(named: 'amount'),
            evidenceUrl: any(named: 'evidenceUrl'),
          )).thenAnswer((_) async => 'sanction-id-456');

      await repository.issueSanction(
        memberId: 'member-2',
        sanctionType: 'suspension',
        reason: 'Rule violation',
        durationDays: 7,
        amount: 50,
        evidenceUrl: 'https://example.com/evidence.png',
      );

      verify(() => mockDataSource.issueSanction(
            memberId: 'member-2',
            sanctionType: 'suspension',
            reason: 'Rule violation',
            durationDays: 7,
            amount: 50,
            evidenceUrl: 'https://example.com/evidence.png',
          )).called(1);
    });

    test('wraps errors in ServerException', () async {
      when(() => mockDataSource.issueSanction(
            memberId: any(named: 'memberId'),
            sanctionType: any(named: 'sanctionType'),
            reason: any(named: 'reason'),
            durationDays: any(named: 'durationDays'),
            amount: any(named: 'amount'),
            evidenceUrl: any(named: 'evidenceUrl'),
          )).thenThrow(Exception('Not authorized'));

      expect(
        () => repository.issueSanction(
          memberId: 'member-1',
          sanctionType: 'warning',
          reason: 'Test',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SanctionsRepositoryImpl.revokeSanction', () {
    test('delegates to data source with correct params', () async {
      when(() => mockDataSource.revokeSanction(
            sanctionId: any(named: 'sanctionId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async {});

      await repository.revokeSanction(
        sanctionId: 'sanction-1',
        reason: 'Resolved',
      );

      verify(() => mockDataSource.revokeSanction(
            sanctionId: 'sanction-1',
            reason: 'Resolved',
          )).called(1);
    });

    test('wraps errors in ServerException', () async {
      when(() => mockDataSource.revokeSanction(
            sanctionId: any(named: 'sanctionId'),
            reason: any(named: 'reason'),
          )).thenThrow(Exception('Sanction not found'));

      expect(
        () => repository.revokeSanction(
          sanctionId: 'nonexistent',
          reason: 'Test',
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SanctionsRepositoryImpl.getSanctions', () {
    test('returns sanctions list from data source', () async {
      final sanctions = [
        Sanction(
          id: 's1',
          targetUserId: 'u1',
          targetRole: 'customer',
          sanctionType: 'warning',
          reason: 'Test',
          startDate: DateTime(2026, 1, 1),
          issuedBy: 'admin-1',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
      when(() => mockDataSource.getSanctions(active: any(named: 'active')))
          .thenAnswer((_) async => sanctions);

      final result = await repository.getSanctions();

      expect(result, sanctions);
      verify(() => mockDataSource.getSanctions(active: null)).called(1);
    });

    test('filters by active status', () async {
      when(() => mockDataSource.getSanctions(active: any(named: 'active')))
          .thenAnswer((_) async => []);

      await repository.getSanctions(active: true);

      verify(() => mockDataSource.getSanctions(active: true)).called(1);
    });
  });
}
