import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/merchant_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/data/datasources/remote/supabase_merchant_data_source.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final merchantRepositoryImplProvider = Provider<MerchantRepositoryImpl>((ref) {
  return MerchantRepositoryImpl(
    ref.watch(supabaseMerchantDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

class MerchantRepositoryImpl implements MerchantRepository {
  MerchantRepositoryImpl(this._dataSource, this._logger);

  final SupabaseMerchantDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Merchant>> getMerchants({
    MerchantType? type,
    String? city,
    bool? isOpenNow,
    SearchFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _dataSource.getMerchants(
        type: type,
        city: city,
        isOpenNow: isOpenNow,
        filter: filter,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      _logger.e('Failed to get merchants', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Merchant?> getMerchantById(String id) async {
    try {
      return await _dataSource.getMerchantById(id);
    } catch (e) {
      _logger.e('Failed to get merchant: $id', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Merchant>> getFeaturedMerchants() async {
    try {
      return await _dataSource.getFeaturedMerchants();
    } catch (e) {
      _logger.e('Failed to get featured merchants', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Merchant>> searchMerchants(String query) async {
    try {
      return await _dataSource.searchMerchants(query);
    } catch (e) {
      _logger.e('Failed to search merchants: $query', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Merchant>> getMerchantsByType(MerchantType type) async {
    try {
      return await _dataSource.getMerchantsByType(type);
    } catch (e) {
      _logger.e('Failed to get merchants by type: ${type.name}', e);
      throw ServerException(message: e.toString());
    }
  }
}
