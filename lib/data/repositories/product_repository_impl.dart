import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_product_data_source.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._dataSource);

  final SupabaseProductDataSource _dataSource;

  @override
  Future<List<Product>> getProducts({
    required String merchantId,
    String? categoryId,
    bool? isAvailable,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _dataSource.getProducts(
        merchantId: merchantId,
        categoryId: categoryId,
        isAvailable: isAvailable,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Product?> getProductById(String id) async {
    try {
      return await _dataSource.getProductById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Product>> getFeaturedProducts(String merchantId) async {
    try {
      return await _dataSource.getFeaturedProducts(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Product>> searchProducts(
    String query, {
    String? merchantId,
  }) async {
    try {
      return await _dataSource.searchProducts(query, merchantId: merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
