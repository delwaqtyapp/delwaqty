import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/merchant_repository.dart';
import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';

class _MockMerchantRepository extends Mock implements MerchantRepository {}

Merchant _merchant({required bool isOpenNow}) => Merchant(
  id: 'm1',
  name: 'Test',
  type: MerchantType.restaurant,
  latitude: 0,
  longitude: 0,
  isOpenNow: isOpenNow,
  createdAt: DateTime(2024),
);

void main() {
  group('merchantOpenStatusProvider', () {
    test('true when the merchant is open', () async {
      final repo = _MockMerchantRepository();
      when(() => repo.getMerchantById('m1'))
          .thenAnswer((_) async => _merchant(isOpenNow: true));
      final container = ProviderContainer(
        overrides: [merchantRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(merchantOpenStatusProvider('m1').future),
        isTrue,
      );
    });

    test('false when the merchant is closed', () async {
      final repo = _MockMerchantRepository();
      when(() => repo.getMerchantById('m1'))
          .thenAnswer((_) async => _merchant(isOpenNow: false));
      final container = ProviderContainer(
        overrides: [merchantRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(merchantOpenStatusProvider('m1').future),
        isFalse,
      );
    });

    test(
      'true on lookup failure (never blocks ordering on an error)',
      () async {
        final repo = _MockMerchantRepository();
        when(() => repo.getMerchantById('m1')).thenThrow(Exception('offline'));
        final container = ProviderContainer(
          overrides: [merchantRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        expect(
          await container.read(merchantOpenStatusProvider('m1').future),
          isTrue,
        );
      },
    );
  });
}
