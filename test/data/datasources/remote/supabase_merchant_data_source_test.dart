import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/datasources/remote/supabase_merchant_data_source.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';

Map<String, dynamic> merchantRow(String type) => {
  'id': 'm-1',
  'name': 'Test Store',
  'type': type,
  'latitude': 30.0,
  'longitude': 31.0,
  'address': null,
  'rating': 4.5,
  'total_reviews': 12,
  'logo_url': null,
  'description': null,
  'status': 'active',
  'is_featured': false,
  'is_open': true,
  'delivery_fee': 10.0,
  'min_order': 50.0,
  'delivery_time_min': 30,
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': null,
};

void main() {
  group('parseMerchantRow', () {
    test('parses a supported merchant type', () {
      final merchant = parseMerchantRow(merchantRow('restaurant'));
      expect(merchant, isNotNull);
      expect(merchant!.type, MerchantType.restaurant);
    });

    test('normalizes legacy aliases', () {
      expect(
        parseMerchantRow(merchantRow('food'))!.type,
        MerchantType.restaurant,
      );
      expect(
        parseMerchantRow(merchantRow('super_market'))!.type,
        MerchantType.supermarket,
      );
    });

    test('fails closed on the retired pharmacy type', () {
      // The pre-purge pharmacy row must never surface as a generic merchant.
      expect(parseMerchantRow(merchantRow('pharmacy')), isNull);
    });

    test('fails closed on unknown types', () {
      expect(parseMerchantRow(merchantRow('alien')), isNull);
      expect(parseMerchantRow(merchantRow('')), isNull);
    });
  });

  group('Merchant.fromJson', () {
    Map<String, dynamic> merchantJson(String type) => {
      'id': 'm-1',
      'name': 'Test Store',
      'type': type,
      'latitude': 30.0,
      'longitude': 31.0,
      'createdAt': '2026-01-01T00:00:00.000Z',
    };

    test('decodes a supported type', () {
      expect(
        Merchant.fromJson(merchantJson('bakery')).type,
        MerchantType.bakery,
      );
    });

    test('never throws on a retired or unknown cached type', () {
      // Cached payloads (Hive, favorites, old order joins) written before a
      // type was retired must decode safely instead of crashing the surface.
      expect(
        Merchant.fromJson(merchantJson('pharmacy')).type,
        MerchantType.other,
      );
      expect(Merchant.fromJson(merchantJson('alien')).type, MerchantType.other);
    });
  });
}
