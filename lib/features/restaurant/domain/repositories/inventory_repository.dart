import 'package:delwaqty/features/restaurant/domain/entities/product_inventory.dart';

abstract interface class InventoryRepository {
  Future<ProductInventory?> getInventory(String productId);
  Future<List<ProductInventory>> getMerchantInventory(String merchantId);
  Future<ProductInventory> updateStock({
    required String productId,
    required String merchantId,
    required int stockQuantity,
  });
  Future<ProductInventory> adjustStock({
    required String productId,
    required int adjustment,
  });
  Future<ProductInventory> reserveStock({
    required String productId,
    required int quantity,
  });
  Future<ProductInventory> releaseStock({
    required String productId,
    required int quantity,
  });
  Future<List<String>> getOutOfStockProductIds(String merchantId);
  Future<List<String>> getLowStockProductIds(String merchantId);
  Stream<ProductInventory> watchInventory(String productId);
}
