import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';

final supabaseCouponDataSourceProvider = Provider<SupabaseCouponDataSource>((
  ref,
) {
  return SupabaseCouponDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseCouponDataSource {
  SupabaseCouponDataSource(this._client);
  final SupabaseClient _client;

  Coupon _fromRow(Map<String, dynamic> row) => Coupon(
    id: row['id'] as String,
    code: row['code'] as String,
    description: row['description'] as String?,
    type: CouponType.values.firstWhere(
      (t) => t.name == (row['discount_type'] as String).replaceAll('-', '_'),
      orElse: () => CouponType.percentage,
    ),
    value: (row['discount_value'] as num).toDouble(),
    minimumOrder: row['minimum_order'] != null
        ? (row['minimum_order'] as num).toDouble()
        : null,
    maximumDiscount: row['maximum_discount'] != null
        ? (row['maximum_discount'] as num).toDouble()
        : null,
    merchantId: row['merchant_id'] as String?,
    branchId: row['branch_id'] as String?,
    productId: row['product_id'] as String?,
    categoryId: row['category_id'] as String?,
    usageLimit: row['usage_limit'] as int?,
    usedCount: row['used_count'] as int? ?? 0,
    expiresAt: row['expires_at'] != null
        ? DateTime.parse(row['expires_at'] as String)
        : null,
    isActive: row['is_active'] as bool? ?? true,
    createdAt: row['created_at'] != null
        ? DateTime.parse(row['created_at'] as String)
        : null,
  );

  CouponStatus _deriveStatus(Coupon coupon) {
    if (!coupon.isActive) return CouponStatus.inactive;
    if (coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now())) {
      return CouponStatus.expired;
    }
    if (coupon.usageLimit != null &&
        coupon.usedCount != null &&
        coupon.usedCount! >= coupon.usageLimit!) {
      return CouponStatus.usedUp;
    }
    return CouponStatus.active;
  }

  Future<List<Coupon>> getAvailableCoupons() async {
    final data = await _client
        .from('coupons')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .where((c) => _deriveStatus(c) == CouponStatus.active)
        .toList();
  }

  Future<Coupon?> getCouponByCode(String code) async {
    final data = await _client
        .from('coupons')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<Coupon?> validateCoupon(String code, double orderTotal) async {
    final coupon = await getCouponByCode(code);
    if (coupon == null) return null;
    if (_deriveStatus(coupon) != CouponStatus.active) return null;
    if (coupon.minimumOrder != null && orderTotal < coupon.minimumOrder!) {
      return null;
    }
    return coupon;
  }

  Future<void> incrementUsage(String code) async {
    await _client
        // The live function signature is increment_coupon_usage(p_coupon_code).
        // The app was sending "coupon_code", so every redemption failed with
        // PGRST202 and silently fell through to the non-atomic read/modify
        // write below — which means limited-use coupons never incremented.
        .rpc('increment_coupon_usage', params: {'p_coupon_code': code})
        .catchError((_) async {
          final coupon = await getCouponByCode(code);
          if (coupon != null && coupon.usedCount != null) {
            await _client
                .from('coupons')
                .update({'used_count': coupon.usedCount! + 1})
                .eq('id', coupon.id);
          }
        });
  }

  Future<List<Coupon>> getMerchantCoupons(String merchantId) async {
    final data = await _client
        .from('coupons')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  CouponStatus getCouponStatus(Coupon coupon) => _deriveStatus(coupon);
}
