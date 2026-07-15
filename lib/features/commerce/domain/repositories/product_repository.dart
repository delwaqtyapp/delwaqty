import 'package:delwaqty/features/commerce/domain/entities/product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts({
    required String merchantId,
    String? categoryId,
    bool? isAvailable,
    int limit = 20,
    int offset = 0,
  });
  Future<Product?> getProductById(String id);
  Future<List<Product>> getFeaturedProducts(String merchantId);
  Future<List<Product>> searchProducts(String query, {String? merchantId});
}
