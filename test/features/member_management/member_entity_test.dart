import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';

void main() {
  group('Member entity parsing', () {
    test('parses all fields from JSON correctly', () {
      final json = {
        'id': 'uuid-123',
        'full_name': 'John Doe',
        'email': 'john@example.com',
        'phone': '+1234567890',
        'username': 'john_doe',
        'avatar_url': 'https://example.com/avatar.jpg',
        'role': 'customer',
        'user_type': 'customer',
        'account_status': 'active',
        'verification_status': 'verified',
        'region_id': 'region-uuid',
        'region_label': 'Cairo / Downtown',
        'last_seen_at': '2026-08-17T22:22:40.267368+00:00',
        'is_online': true,
        'service_types': ['food_delivery', 'retail_delivery'],
        'service_categories': ['restaurant', 'grocery'],
        'orders_count': 5,
        'rides_count': 2,
        'bookings_count': 1,
        'wallet_balance': 1250.5,
        'wallet_currency': 'SAR',
        'active_sanctions_count': 0,
        'created_at': '2026-08-17T12:00:00.000Z',
      };

      final member = Member.fromJson(json);

      expect(member.id, 'uuid-123');
      expect(member.fullName, 'John Doe');
      expect(member.email, 'john@example.com');
      expect(member.phone, '+1234567890');
      expect(member.username, 'john_doe');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
      expect(member.role, 'customer');
      expect(member.userType, 'customer');
      expect(member.accountStatus, 'active');
      expect(member.verificationStatus, 'verified');
      expect(member.regionId, 'region-uuid');
      expect(member.regionLabel, 'Cairo / Downtown');
      expect(member.lastSeenAt, isNotNull);
      expect(member.isOnline, true);
      expect(member.serviceTypes, ['food_delivery', 'retail_delivery']);
      expect(member.serviceCategories, ['restaurant', 'grocery']);
      expect(member.ordersCount, 5);
      expect(member.ridesCount, 2);
      expect(member.bookingsCount, 1);
      expect(member.walletBalance, 1250.5);
      expect(member.walletCurrency, 'SAR');
      expect(member.activeSanctionsCount, 0);
      expect(member.createdAt, DateTime.utc(2026, 8, 17, 12));
    });

    test('handles null fields gracefully', () {
      final json = <String, dynamic>{
        'id': 'uuid-456',
        'created_at': '2026-01-01T00:00:00.000Z',
      };

      final member = Member.fromJson(json);

      expect(member.id, 'uuid-456');
      expect(member.fullName, isNull);
      expect(member.email, isNull);
      expect(member.role, 'customer');
      expect(member.accountStatus, 'active');
      expect(member.verificationStatus, 'unverified');
      expect(member.ordersCount, isNull);
      expect(member.walletBalance, isNull);
    });

    test('toJson roundtrips correctly', () {
      final original = Member(
        id: 'test-id',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'driver',
        accountStatus: 'active',
        verificationStatus: 'verified',
        createdAt: DateTime.utc(2026, 8, 18),
      );

      final json = original.toJson();
      final restored = Member.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.fullName, original.fullName);
      expect(restored.email, original.email);
      expect(restored.role, original.role);
    });

    test('parses member_ops_list rows with dynamic-typed arrays', () {
      final rows = [
        {
          'id': 'uuid-1',
          'full_name': 'User One',
          'email': 'one@example.com',
          'role': 'customer',
          'user_type': 'customer',
          'account_status': 'active',
          'verification_status': 'unverified',
          'is_online': false,
          'service_types': <dynamic>[],
          'service_categories': <dynamic>[],
          'orders_count': 0,
          'rides_count': 0,
          'bookings_count': 0,
          'wallet_balance': null,
          'active_sanctions_count': 0,
          'created_at': '2026-08-17T12:00:00.000Z',
        },
        {
          'id': 'uuid-2',
          'full_name': 'Active Driver',
          'email': 'driver@example.com',
          'role': 'delivery',
          'user_type': 'delivery_user',
          'account_status': 'suspended',
          'verification_status': 'verified',
          'is_online': true,
          'service_types': <dynamic>['food_delivery', 'retail_delivery'],
          'service_categories': <dynamic>['restaurant'],
          'orders_count': 12,
          'rides_count': 3,
          'bookings_count': 0,
          'wallet_balance': 500,
          'active_sanctions_count': 1,
          'created_at': '2026-08-16T10:00:00.000Z',
        },
      ];

      final members = rows.map(Member.fromJson).toList();

      expect(members, hasLength(2));
      expect(members[0].serviceTypes, isEmpty);
      expect(members[0].serviceCategories, isEmpty);
      expect(members[1].serviceTypes, ['food_delivery', 'retail_delivery']);
      expect(members[1].serviceCategories, ['restaurant']);
      expect(members[1].isOnline, true);
      expect(members[1].walletBalance, 500);
      expect(members[1].createdAt, DateTime.utc(2026, 8, 16, 10));
    });
  });
}
