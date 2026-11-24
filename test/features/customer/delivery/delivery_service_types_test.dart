import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/customer/delivery/data/datasources/remote/supabase_delivery_data_source.dart';

void main() {
  group('supported delivery service types', () {
    test('every non-retired type in the rides constraint survives', () {
      // Mirrors the rides.service_type check constraint (000_baseline)
      // minus 'ride' and the retired 'pharmacy_delivery'.
      const expected = {
        'food_delivery',
        'grocery_delivery',
        'marketplace_delivery',
        'courier',
        'package_delivery',
        'document_delivery',
        'flower_delivery',
        'retail_delivery',
      };
      for (final type in expected) {
        expect(
          SupabaseDeliveryDataSource.isSupportedDeliveryServiceType(type),
          isTrue,
          reason: '$type must stay visible to captains',
        );
      }
      expect(
        SupabaseDeliveryDataSource.supportedDeliveryServiceTypes,
        expected,
      );
    });

    test('the type the client inserts for ask-anything is supported', () {
      // requestCourierDelivery inserts 'courier'; if this breaks, courier
      // offers vanish from the captain stream.
      expect(
        SupabaseDeliveryDataSource.isSupportedDeliveryServiceType('courier'),
        isTrue,
      );
    });

    test('ride, pharmacy_delivery and unknown types are filtered', () {
      for (final type in ['ride', 'pharmacy_delivery', 'alien']) {
        expect(
          SupabaseDeliveryDataSource.isSupportedDeliveryServiceType(type),
          isFalse,
          reason: '$type must never surface as a delivery',
        );
      }
      expect(
        SupabaseDeliveryDataSource.isSupportedDeliveryServiceType(null),
        isFalse,
      );
    });
  });
}
