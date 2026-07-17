import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/features/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/commerce/domain/repositories/cart_repository.dart';

final localCartRepositoryProvider = Provider<LocalCartRepository>((ref) {
  return LocalCartRepository();
});

class LocalCartRepository implements CartRepository {
  static const String _cartKey = 'local_cart';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _getPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Cart? _cart;

  @override
  Future<Cart?> getCurrentCart() async {
    if (_cart != null) return _cart;
    try {
      final prefs = await _getPrefs;
      final json = prefs.getString(_cartKey);
      if (json == null) return null;
      _cart = Cart.fromJson(jsonDecode(json) as Map<String, dynamic>);
      return _cart;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCart() async {
    final prefs = await _getPrefs;
    if (_cart == null) {
      await prefs.remove(_cartKey);
    } else {
      await prefs.setString(_cartKey, jsonEncode(_cart!.toJson()));
    }
  }

  @override
  Future<Cart> addToCart({
    required String merchantId,
    required String merchantName,
    required CartItem item,
  }) async {
    if (_cart != null && _cart!.merchantId != merchantId) {
      _cart = _createNewCart(merchantId, merchantName, item);
    } else if (_cart == null) {
      _cart = _createNewCart(merchantId, merchantName, item);
    } else {
      final existingIndex = _cart!.items.indexWhere(
        (i) => i.productId == item.productId,
      );
      if (existingIndex >= 0) {
        final existing = _cart!.items[existingIndex];
        final updated = existing.copyWith(
          quantity: existing.quantity + item.quantity,
        );
        final items = List<CartItem>.from(_cart!.items);
        items[existingIndex] = updated;
        _cart = _rebuildCart(items);
      } else {
        _cart = _rebuildCart([..._cart!.items, item]);
      }
    }
    await _saveCart();
    return _cart!;
  }

  @override
  Future<Cart> updateCartItem({
    required String cartItemId,
    required int quantity,
  }) async {
    if (_cart == null) throw StateError('No active cart');
    if (quantity <= 0) return removeFromCart(cartItemId: cartItemId);
    final items = _cart!.items.map((item) {
      if (item.id == cartItemId) return item.copyWith(quantity: quantity);
      return item;
    }).toList();
    _cart = _rebuildCart(items);
    await _saveCart();
    return _cart!;
  }

  @override
  Future<Cart> removeFromCart({required String cartItemId}) async {
    if (_cart == null) throw StateError('No active cart');
    final items = _cart!.items.where((i) => i.id != cartItemId).toList();
    if (items.isEmpty) {
      _cart = null;
      await _saveCart();
      return Cart(
        id: 'empty',
        merchantId: '',
        merchantName: '',
        items: [],
        updatedAt: DateTime.now(),
      );
    }
    _cart = _rebuildCart(items);
    await _saveCart();
    return _cart!;
  }

  @override
  Future<Cart> clearCart() async {
    _cart = null;
    await _saveCart();
    return Cart(
      id: 'empty',
      merchantId: '',
      merchantName: '',
      items: [],
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Cart> applyCoupon(String couponCode) async {
    if (_cart == null) throw StateError('No active cart');
    final discount = _cart!.subtotal * 0.1;
    _cart = _cart!.copyWith(
      couponCode: couponCode,
      discount: discount,
      total: _cart!.subtotal + _cart!.deliveryFee - discount,
      updatedAt: DateTime.now(),
    );
    await _saveCart();
    return _cart!;
  }

  @override
  Future<Cart> removeCoupon() async {
    if (_cart == null) throw StateError('No active cart');
    _cart = _cart!.copyWith(
      couponCode: null,
      discount: 0,
      total: _cart!.subtotal + _cart!.deliveryFee,
      updatedAt: DateTime.now(),
    );
    await _saveCart();
    return _cart!;
  }

  Cart _createNewCart(String merchantId, String merchantName, CartItem item) {
    return Cart(
      id: 'cart_${DateTime.now().millisecondsSinceEpoch}',
      merchantId: merchantId,
      merchantName: merchantName,
      items: [item],
      subtotal: item.unitPrice * item.quantity,
      total: item.unitPrice * item.quantity,
      updatedAt: DateTime.now(),
    );
  }

  Cart _rebuildCart(List<CartItem> items) {
    final subtotal = items.fold(
      0.0,
      (sum, i) => sum + i.unitPrice * i.quantity,
    );
    final discount = _cart?.discount ?? 0;
    return _cart!.copyWith(
      items: items,
      subtotal: subtotal,
      total: subtotal + _cart!.deliveryFee - discount,
      updatedAt: DateTime.now(),
    );
  }
}
