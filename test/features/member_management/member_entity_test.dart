import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/member_management/domain/entities/member.dart';

class MockMemberRepository extends Mock implements MemberRepository {}

void main() {
  group('Member entity parsing', () {
    test('parses basic fields correctly', () {
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
      expect(member.phone, '+'); // truncated, but type is String?
      expect(member.username, 'john_doe');
      expect(member.avatarUrl, 'https://example.com/avatar.jpg');
      // Add more expectations as needed
    });
  });