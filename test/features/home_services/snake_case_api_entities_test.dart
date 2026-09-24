import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_booking.dart';

void main() {
  group('snake_case API rows', () {
    test('ServiceCategory.fromJson parses real service_categories row', () {
      final row = <String, dynamic>{
        'id': 'cat-1',
        'name_ar': 'سباكة',
        'name_en': 'Plumbing',
        'type': 'plumbing',
        'description_ar': null,
        'description_en': null,
        'icon_url': null,
        'is_active': true,
        'created_at': '2026-07-17T21:46:03.2872+00:00',
      };
      final cat = ServiceCategory.fromJson(row);
      expect(cat.nameAr, 'سباكة');
      expect(cat.nameEn, 'Plumbing');
      expect(cat.type, ServiceCategoryType.plumbing);
      expect(cat.isActive, isTrue);
    });

    test('ServiceProvider.fromJson parses real service_providers row', () {
      final row = <String, dynamic>{
        'id': 'prov-1',
        'user_id': 'u-1',
        'name': 'أحمد',
        'category_type': 'plumbing',
        'description': null,
        'profile_image_url': null,
        'rating': 4.5,
        'rating_count': 10,
        'is_verified': true,
        'is_available': true,
        'hourly_rate': 50.0,
        'fixed_price_min': null,
        'fixed_price_max': null,
        'city': 'القاهرة',
        'latitude': 30.0,
        'longitude': 31.0,
        'tags': null,
        'created_at': '2026-07-17T21:46:03.2872+00:00',
        'updated_at': null,
      };
      final p = ServiceProvider.fromJson(row);
      expect(p.name, 'أحمد');
      expect(p.categoryType, ServiceCategoryType.plumbing);
      expect(p.rating, 4.5);
    });

    test('ServiceBooking.fromJson parses real service_bookings row', () {
      final row = <String, dynamic>{
        'id': 'bk-1',
        'user_id': 'u-1',
        'provider_id': 'prov-1',
        'provider_name': 'أحمد',
        'category_type': 'plumbing',
        'status': 'pending',
        'description': null,
        'scheduled_date': '2026-09-20T10:00:00.000Z',
        'scheduled_time': '10:00',
        'address': 'شارع 1',
        'address_latitude': null,
        'address_longitude': null,
        'estimated_price': 100.0,
        'final_price': null,
        'notes': null,
        'created_at': '2026-09-19T10:00:00.000Z',
        'updated_at': null,
        'completed_at': null,
      };
      final b = ServiceBooking.fromJson(row);
      expect(b.providerName, 'أحمد');
      expect(b.status, BookingStatus.pending);
    });

    test('ServiceProvider.fromJson tolerates unknown category_type', () {
      final row = <String, dynamic>{
        'id': 'prov-2',
        'user_id': 'u-2',
        'name': 'Owner',
        'category_type': 'home_services',
        'description': null,
        'profile_image_url': null,
        'rating': 0.0,
        'rating_count': 0,
        'is_verified': true,
        'is_available': false,
        'hourly_rate': null,
        'fixed_price_min': null,
        'fixed_price_max': null,
        'city': null,
        'latitude': null,
        'longitude': null,
        'tags': [],
        'created_at': '2026-09-19T10:00:00.000Z',
        'updated_at': null,
      };
      final p = ServiceProvider.fromJson(row);
      expect(p.categoryType, ServiceCategoryType.other);
    });

    test('ServiceProvider.fromJson tolerates NULL user_id like seeded rows', () {
      final row = <String, dynamic>{
        'id': 'prov-seed-1',
        'user_id': null,
        'name': 'د. أحمد حسن',
        'category_type': 'doctor',
        'description': null,
        'profile_image_url': null,
        'rating': 4.2,
        'rating_count': null,
        'is_verified': null,
        'is_available': null,
        'hourly_rate': 250.0,
        'fixed_price_min': null,
        'fixed_price_max': null,
        'city': null,
        'latitude': null,
        'longitude': null,
        'tags': null,
        'created_at': '2026-09-19T08:22:46.711516+00:00',
        'updated_at': null,
      };
      final p = ServiceProvider.fromJson(row);
      expect(p.userId, isEmpty);
      expect(p.name, 'د. أحمد حسن');
    });
  });
}