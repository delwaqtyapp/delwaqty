import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';

abstract interface class MerchantRepository {
  Future<List<Merchant>> getMerchants({
    MerchantType? type,
    String? city,
    bool? isOpenNow,
    SearchFilter? filter,
    int limit = 20,
    int offset = 0,
  });
  Future<Merchant?> getMerchantById(String id);
  Future<List<Merchant>> getFeaturedMerchants();
  Future<List<Merchant>> searchMerchants(String query);
  Future<List<Merchant>> getMerchantsByType(MerchantType type);
}
