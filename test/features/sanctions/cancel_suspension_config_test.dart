import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/admin/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart';
import 'package:delwaqty/features/admin/sanctions/data/repositories/sanctions_repository_impl.dart';

class MockSanctionsDataSource extends Mock
    implements SupabaseSanctionsDataSource {}

void main() {
  late MockSanctionsDataSource mockDataSource;
  late SanctionsRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockSanctionsDataSource();
    repository = SanctionsRepositoryImpl(mockDataSource);
  });

  group('SanctionsRepositoryImpl.getCancelSuspensionDays', () {
    test('returns the configured duration', () async {
      when(
        () => mockDataSource.getCancelSuspensionDays(),
      ).thenAnswer((_) async => 7);

      final result = await repository.getCancelSuspensionDays();

      expect(result, 7);
      verify(() => mockDataSource.getCancelSuspensionDays()).called(1);
    });

    test('wraps data source errors in ServerException', () async {
      when(
        () => mockDataSource.getCancelSuspensionDays(),
      ).thenThrow(Exception('network'));

      expect(
        () => repository.getCancelSuspensionDays(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SanctionsRepositoryImpl.setCancelSuspensionDays', () {
    test('delegates to data source with days and reason', () async {
      when(
        () => mockDataSource.setCancelSuspensionDays(
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => 10);

      final result = await repository.setCancelSuspensionDays(
        10,
        reason: 'extend after review',
      );

      expect(result, 10);
      verify(
        () => mockDataSource.setCancelSuspensionDays(
          10,
          reason: 'extend after review',
        ),
      ).called(1);
    });

    test('omitted reason passes null through', () async {
      when(
        () => mockDataSource.setCancelSuspensionDays(
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => 5);

      await repository.setCancelSuspensionDays(5);

      verify(
        () => mockDataSource.setCancelSuspensionDays(5, reason: null),
      ).called(1);
    });

    test('wraps owner-only rejection in ServerException', () async {
      when(
        () => mockDataSource.setCancelSuspensionDays(
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        Exception(
          'Only the platform owner can change the cancellation suspension duration',
        ),
      );

      expect(
        () => repository.setCancelSuspensionDays(9),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('SanctionsRepositoryImpl refusal suspension config', () {
    test('getRefusalSuspensionDays returns the configured duration', () async {
      when(
        () => mockDataSource.getRefusalSuspensionDays(),
      ).thenAnswer((_) async => 4);

      final result = await repository.getRefusalSuspensionDays();

      expect(result, 4);
      verify(() => mockDataSource.getRefusalSuspensionDays()).called(1);
    });

    test('setRefusalSuspensionDays delegates with days and reason', () async {
      when(
        () => mockDataSource.setRefusalSuspensionDays(
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => 3);

      final result = await repository.setRefusalSuspensionDays(
        3,
        reason: 'shorten after review',
      );

      expect(result, 3);
      verify(
        () => mockDataSource.setRefusalSuspensionDays(
          3,
          reason: 'shorten after review',
        ),
      ).called(1);
    });

    test('wraps owner-only rejection in ServerException', () async {
      when(
        () => mockDataSource.setRefusalSuspensionDays(
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(
        Exception(
          'Only the platform owner can change the refusal suspension duration',
        ),
      );

      expect(
        () => repository.setRefusalSuspensionDays(9),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
