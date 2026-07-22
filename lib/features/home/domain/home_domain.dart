import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';

final nearbyMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants(limit: 20);
});
