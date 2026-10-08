import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/cart_repository.dart';

/// Single source of truth for the shopping cart.
///
/// This was a `StreamProvider` that yielded the cart exactly once and was
/// never invalidated, so the cart badge and the sticky "view cart" bar
/// stayed empty for the whole session even after items were added. Making
/// it an `AsyncNotifier` means every mutation goes through this class and
/// therefore refreshes every listener automatically.
class CartNotifier extends AsyncNotifier<Cart?> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<Cart?> build() => _repo.getCurrentCart();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.getCurrentCart);
  }

  Future<void> addToCart({
    required String merchantId,
    required String merchantName,
    required CartItem item,
  }) async {
    final cart = await _repo.addToCart(
      merchantId: merchantId,
      merchantName: merchantName,
      item: item,
    );
    state = AsyncValue.data(cart);
  }

  Future<void> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    final cart = await _repo.updateCartItem(
      cartItemId: cartItemId,
      quantity: quantity,
    );
    state = AsyncValue.data(cart);
  }

  Future<void> removeItem(String cartItemId) async {
    final cart = await _repo.removeFromCart(cartItemId: cartItemId);
    state = AsyncValue.data(cart);
  }

  Future<void> clear() async {
    final cart = await _repo.clearCart();
    state = AsyncValue.data(cart);
  }

  Future<void> applyCoupon(String couponCode, {double discount = 0}) async {
    final cart = await _repo.applyCoupon(couponCode, discount: discount);
    state = AsyncValue.data(cart);
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(CartNotifier.new);

/// Convenience view: just the cart, ignoring loading/error states.
final currentCartProvider = Provider<Cart?>(
  (ref) => ref.watch(cartProvider).asData?.value,
);