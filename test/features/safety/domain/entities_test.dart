import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/safety/domain/entities/trusted_contact.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  group('ContactRelationship', () {
    test('enum has all values', () {
      expect(ContactRelationship.values.length, 4);
      expect(ContactRelationship.family.name, 'family');
      expect(ContactRelationship.friend.name, 'friend');
      expect(ContactRelationship.colleague.name, 'colleague');
      expect(ContactRelationship.other.name, 'other');
    });
  });

  group('NotificationPreference', () {
    test('enum has all values', () {
      expect(NotificationPreference.values.length, 4);
      expect(NotificationPreference.sms.name, 'sms');
      expect(NotificationPreference.call.name, 'call');
      expect(NotificationPreference.push.name, 'push');
      expect(NotificationPreference.both.name, 'both');
    });
  });

  group('TrustedContact', () {
    test('fromJson creates TrustedContact from JSON', () {
      final json = {
        'id': 'tc1',
        'userId': 'u1',
        'name': 'Ahmed',
        'phone': '+20123456789',
        'email': 'ahmed@example.com',
        'relationship': 'family',
        'notifyOnRide': true,
        'notificationPreference': 'both',
        'createdAt': now.toIso8601String(),
      };

      final contact = TrustedContact.fromJson(json);
      expect(contact.id, 'tc1');
      expect(contact.userId, 'u1');
      expect(contact.name, 'Ahmed');
      expect(contact.phone, '+20123456789');
      expect(contact.email, 'ahmed@example.com');
      expect(contact.relationship, ContactRelationship.family);
      expect(contact.notifyOnRide, true);
      expect(contact.notificationPreference, NotificationPreference.both);
    });

    test('toJson serializes correctly', () {
      final contact = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        relationship: ContactRelationship.friend,
        createdAt: now,
      );

      final json = contact.toJson();
      expect(json['id'], 'tc1');
      expect(json['userId'], 'u1');
      expect(json['name'], 'Ahmed');
      expect(json['relationship'], 'friend');
      expect(json['notifyOnRide'], true);
      expect(json['notificationPreference'], 'both');
      expect(json['email'], isNull);
    });

    test('fromJson roundtrip preserves data', () {
      final original = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        email: 'ahmed@example.com',
        relationship: ContactRelationship.family,
        notifyOnRide: false,
        notificationPreference: NotificationPreference.sms,
        createdAt: now,
      );

      final restored = TrustedContact.fromJson(original.toJson());
      expect(restored, original);
    });

    test('equality works correctly', () {
      final a = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        relationship: ContactRelationship.family,
        createdAt: now,
      );
      final b = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        relationship: ContactRelationship.family,
        createdAt: now,
      );
      final c = TrustedContact(
        id: 'tc2',
        userId: 'u2',
        name: 'Sara',
        phone: '+20987654321',
        createdAt: now,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      final contact = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        relationship: ContactRelationship.friend,
        createdAt: now,
      );

      final updated = contact.copyWith(
        name: 'Mohamed',
        relationship: ContactRelationship.colleague,
        notifyOnRide: false,
      );
      expect(updated.name, 'Mohamed');
      expect(updated.relationship, ContactRelationship.colleague);
      expect(updated.notifyOnRide, false);
      expect(updated.id, 'tc1');
      expect(updated.phone, '+20123456789');
      expect(contact.name, 'Ahmed');
    });

    test('defaults are applied correctly', () {
      final contact = TrustedContact(
        id: 'tc1',
        userId: 'u1',
        name: 'Ahmed',
        phone: '+20123456789',
        createdAt: now,
      );

      expect(contact.notifyOnRide, true);
      expect(contact.notificationPreference, NotificationPreference.both);
      expect(contact.email, isNull);
      expect(contact.relationship, isNull);
    });
  });
}
