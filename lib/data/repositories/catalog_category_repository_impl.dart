import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/catalog_category_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/data/datasources/remote/supabase_catalog_category_data_source.dart';
import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final catalogCategoryRepositoryImplProvider =
    Provider<CatalogCategoryRepositoryImpl>((ref) {
      return CatalogCategoryRepositoryImpl(
        ref.watch(supabaseCatalogCategoryDataSourceProvider),
        ref.watch(loggerProvider),
      );
    });

class CatalogCategoryRepositoryImpl implements CatalogCategoryRepository {
  CatalogCategoryRepositoryImpl(this._dataSource, this._logger);

  final SupabaseCatalogCategoryDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<CatalogCategory>> getCategories(String merchantId) async {
    try {
      return await _dataSource.getCategories(merchantId);
    } catch (e) {
      _logger.e('Failed to get catalog categories for $merchantId', e);
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CatalogCategory?> getCategoryById(String id) async {
    try {
      return await _dataSource.getCategoryById(id);
    } catch (e) {
      _logger.e('Failed to get catalog category: $id', e);
      throw ServerException(message: e.toString());
    }
  }
}
