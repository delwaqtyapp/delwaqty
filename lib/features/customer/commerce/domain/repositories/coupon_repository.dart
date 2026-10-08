import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';

abstract interface class CouponRepository {
  Future<List<Coupon>> getAvailableCoupons();
  Future<Coupon?> getCouponByCode(String code);
  Future<Coupon?> validateCoupon(String code, double orderTotal);
  Future<Coupon> applyCoupon(String code, double orderTotal);
  Future<List<Coupon>> getMerchantCoupons(String merchantId);
  Future<CouponStatus> getCouponStatus(String code);
}
