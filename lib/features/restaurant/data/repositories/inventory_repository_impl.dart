import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_inventory_data_source.dart';
import 'package:delwaqty/features/restaurant/domain/entities/product_inventory.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dataSource);
  final SupabaseInventoryDataSource _dataSource;

  @override
  Future<ProductInventory?> getInventory(String productId) async {
    try {
      return await _dataSource.getInventory(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<ProductInventory>> getMerchantInventory(String merchantId) async {
    try {
      return await _dataSource.getMerchantInventory(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductInventory> updateStock({
    required String productId,
    required String merchantId,
    required int stockQuantity,
  }) async {
    try {
      final existing = await _dataSource.getInventory(productId);
      final resolvedMerchantId = merchantId.isNotEmpty
          ? merchantId
          : (existing?.merchantId ?? '');
      if (resolvedMerchantId.isEmpty) {
        throw ServerException(
          message: 'merchantId is required for new inventory',
        );
      }
      return await _dataSource.upsertInventory(
        productId: productId,
        merchantId: resolvedMerchantId,
        stockQuantity: stockQuantity,
        isInStock: stockQuantity > 0,
        lowStockThreshold: existing?.lowStockThreshold ?? 10,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductInventory> adjustStock({
    required String productId,
    required int adjustment,
  }) async {
    try {
      return await _dataSource.adjustStock(
        productId: productId,
        adjustment: adjustment,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductInventory> reserveStock({
    required String productId,
    required int quantity,
  }) async {
    try {
      return await _dataSource.reserveStock(
        productId: productId,
        quantity: quantity,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ProductInventory> releaseStock({
    required String productId,
    required int quantity,
  }) async {
    try {
      return await _dataSource.releaseStock(
        productId: productId,
        quantity: quantity,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<String>> getOutOfStockProductIds(String merchantId) async {
    try {
      return await _dataSource.getOutOfStockProductIds(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<String>> getLowStockProductIds(String merchantId) async {
    try {
      return await _dataSource.getLowStockProductIds(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Stream<ProductInventory> watchInventory(String productId) {
    return _dataSource.watchInventory(productId);
  }
}
