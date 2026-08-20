import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/complaints/domain/entities/complaint.dart';

void main() {
  group('Complaint', () {
    test('parses escalation fields from JSON', () {
      final complaint = Complaint.fromJson({
        'id': 'c1',
        'complainant_id': 'u1',
        'complaint_type': 'delivery',
        'subject': 'Late package',
        'description': 'Package arrived 3 days late',
        'status': 'escalated',
        'priority': 'high',
        'assigned_admin_id': 'admin-2',
        'escalated_at': '2026-08-18T10:00:00Z',
        'escalated_from_admin_id': 'admin-1',
        'created_at': '2026-08-18T09:00:00Z',
      });

      expect(complaint.status, 'escalated');
      expect(complaint.assignedAdminId, 'admin-2');
      expect(complaint.escalatedAt, DateTime.parse('2026-08-18T10:00:00Z'));
      expect(complaint.escalatedFromAdminId, 'admin-1');
      expect(complaint.isClosed, isFalse);
    });

    test('serializes escalation fields in toJson', () {
      final complaint = Complaint(
        id: 'c1',
        complainantId: 'u1',
        complaintType: 'delivery',
        subject: 'Late package',
        description: 'Package arrived 3 days late',
        status: 'escalated',
        assignedAdminId: 'admin-2',
        escalatedAt: DateTime.parse('2026-08-18T10:00:00Z'),
        escalatedFromAdminId: 'admin-1',
        createdAt: DateTime.parse('2026-08-18T09:00:00Z'),
      );

      final json = complaint.toJson();

      expect(json['status'], 'escalated');
      expect(json['assigned_admin_id'], 'admin-2');
      expect(json['escalated_at'], '2026-08-18T10:00:00.000Z');
      expect(json['escalated_from_admin_id'], 'admin-1');
    });

    test('isClosed reports terminal states', () {
      final resolved = Complaint(
        id: 'c1',
        complainantId: 'u1',
        complaintType: 'delivery',
        subject: 's',
        description: 'd',
        status: 'resolved',
        createdAt: DateTime(2026, 8, 18),
      );
      final pending = Complaint(
        id: 'c2',
        complainantId: 'u1',
        complaintType: 'delivery',
        subject: 's',
        description: 'd',
        createdAt: DateTime(2026, 8, 18),
      );

      expect(resolved.isClosed, isTrue);
      expect(pending.isClosed, isFalse);
    });
  });
}