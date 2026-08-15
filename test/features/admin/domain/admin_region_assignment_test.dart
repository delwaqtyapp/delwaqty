import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';

void main() {
  group('AdminRegionScope', () {
    test('fromCode maps values', () {
      expect(AdminRegionScope.fromCode('self'), AdminRegionScope.self);
      expect(
        AdminRegionScope.fromCode('descendants'),
        AdminRegionScope.descendants,
      );
      expect(AdminRegionScope.fromCode(null), AdminRegionScope.descendants);
      expect(AdminRegionScope.fromCode('bogus'), AdminRegionScope.descendants);
    });

    test('codes are stable', () {
      expect(AdminRegionScope.self.code, 'self');
      expect(AdminRegionScope.descendants.code, 'descendants');
    });
  });

  group('AdminRegionAssignment', () {
    final now = DateTime(2026, 8, 15);

    test('fromJson creates assignment from JSON', () {
      final json = {
        'adminId': 'a1',
        'regionId': 'r1',
        'scope': 'self',
        'createdAt': now.toIso8601String(),
        'createdBy': 'a2',
      };

      final assignment = AdminRegionAssignment.fromJson(json);
      expect(assignment.adminId, 'a1');
      expect(assignment.regionId, 'r1');
      expect(assignment.scope, AdminRegionScope.self);
      expect(assignment.createdAt, now);
      expect(assignment.createdBy, 'a2');
    });

    test('toJson serializes correctly', () {
      final assignment = AdminRegionAssignment(
        adminId: 'a1',
        regionId: 'r1',
        scope: AdminRegionScope.descendants,
        createdAt: now,
      );

      final json = assignment.toJson();
      expect(json['adminId'], 'a1');
      expect(json['regionId'], 'r1');
      expect(json['scope'], 'descendants');
      expect(json['createdBy'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = AdminRegionAssignment(
        adminId: 'a1',
        regionId: 'r1',
        scope: AdminRegionScope.self,
        createdAt: now,
        createdBy: 'a2',
      );

      final restored = AdminRegionAssignment.fromJson(original.toJson());
      expect(restored, original);
    });
  });
}
