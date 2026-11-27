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

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart?>(
  CartNotifier.new,
);

/// Whether a merchant currently accepts orders (`merchants.is_open`).
///
/// Powers the closed-merchant guard on the add-to-cart surfaces: the server
/// already rejects orders from closed merchants (create_order), this keeps
/// customers from filling a cart they cannot check out. A failed or missing
/// lookup resolves to `true` so a transient error never blocks ordering.
final merchantOpenStatusProvider = FutureProvider.family<bool, String>((
  ref,
  merchantId,
) async {
  try {
    final merchant = await ref
        .watch(merchantRepositoryProvider)
        .getMerchantById(merchantId);
    return merchant?.isOpenNow ?? true;
  } catch (_) {
    return true;
  }
});

/// Convenience view: just the cart, ignoring loading/error states.
final currentCartProvider = Provider<Cart?>(
  (ref) => ref.watch(cartProvider).asData?.value,
);

/// The current cart merchant's minimum order (EGP), when the merchant sets
/// one. Powers the "add X more to reach the minimum" indicator in the cart;
/// the server still enforces the floor at order placement
/// (create_order -> BELOW_MIN_ORDER), this only surfaces it earlier.
final cartMerchantMinOrderProvider = FutureProvider<double?>((ref) async {
  final cart = ref.watch(currentCartProvider);
  if (cart == null) return null;
  final merchant = await ref
      .watch(merchantRepositoryProvider)
      .getMerchantById(cart.merchantId);
  return merchant?.minimumOrder;
});

/// Amount still missing to reach [minimumOrder], or `null` when there is no
/// minimum or the subtotal already covers it. Zero counts as "no minimum".
double? minOrderShortfall(double subtotal, double? minimumOrder) {
  if (minimumOrder == null || minimumOrder <= 0) return null;
  final remaining = minimumOrder - subtotal;
  return remaining > 0 ? remaining : null;
}
