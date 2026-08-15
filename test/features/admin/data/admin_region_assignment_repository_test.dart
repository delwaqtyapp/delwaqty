import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/admin/data/datasources/remote/supabase_admin_region_assignment_data_source.dart';
import 'package:delwaqty/features/admin/data/repositories/admin_region_assignment_repository_impl.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';

class MockDataSource extends Mock implements AdminRegionAssignmentDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(AdminRegionScope.descendants);
  });

  late MockDataSource dataSource;
  late AdminRegionAssignmentRepositoryImpl repository;

  setUp(() {
    dataSource = MockDataSource();
    repository = AdminRegionAssignmentRepositoryImpl(dataSource);
  });

  group('getAssignments', () {
    test('delegates without admin filter', () async {
      when(() => dataSource.getAssignments()).thenAnswer(
        (_) async => <AdminRegionAssignment>[],
      );

      final result = await repository.getAssignments();

      expect(result, isEmpty);
      verify(() => dataSource.getAssignments()).called(1);
    });

    test('delegates with admin filter', () async {
      when(() => dataSource.getAssignments(adminId: 'a1')).thenAnswer(
        (_) async => [
          AdminRegionAssignment(
            adminId: 'a1',
            regionId: 'r1',
            scope: AdminRegionScope.self,
            createdAt: DateTime(2026, 8, 15),
          ),
        ],
      );

      final result = await repository.getAssignments(adminId: 'a1');

      expect(result.single.adminId, 'a1');
      expect(result.single.regionId, 'r1');
      expect(result.single.scope, AdminRegionScope.self);
      verify(() => dataSource.getAssignments(adminId: 'a1')).called(1);
    });
  });

  group('upsertAssignment', () {
    test('delegates scope to data source', () async {
      when(
        () => dataSource.upsertAssignment(
          adminId: any(named: 'adminId'),
          regionId: any(named: 'regionId'),
          scope: any(named: 'scope'),
        ),
      ).thenAnswer((_) async {});

      await repository.upsertAssignment(
        adminId: 'a1',
        regionId: 'r1',
        scope: AdminRegionScope.descendants,
      );

      verify(
        () => dataSource.upsertAssignment(
          adminId: 'a1',
          regionId: 'r1',
          scope: AdminRegionScope.descendants,
        ),
      ).called(1);
    });
  });

  group('deleteAssignment', () {
    test('delegates admin and region ids', () async {
      when(
        () => dataSource.deleteAssignment(
          adminId: any(named: 'adminId'),
          regionId: any(named: 'regionId'),
        ),
      ).thenAnswer((_) async {});

      await repository.deleteAssignment(adminId: 'a1', regionId: 'r1');

      verify(
        () => dataSource.deleteAssignment(adminId: 'a1', regionId: 'r1'),
      ).called(1);
    });
  });
}
