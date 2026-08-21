import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';

abstract interface class CartRepository {
  Future<Cart?> getCurrentCart();
  Future<Cart> addToCart({
    required String merchantId,
    required String merchantName,
    required CartItem item,
  });
  Future<Cart> updateCartItem({
    required String cartItemId,
    required int quantity,
  });
  Future<Cart> removeFromCart({required String cartItemId});
  Future<Cart> clearCart();
  Future<Cart> applyCoupon(String couponCode, {double discount = 0});
  Future<Cart> removeCoupon();
}
