import 'package:delwaqty/features/commerce/domain/entities/coupon.dart';

abstract interface class CouponRepository {
  Future<List<Coupon>> getAvailableCoupons();
  Future<Coupon?> getCouponByCode(String code);
  Future<Coupon?> validateCoupon(String code, double orderTotal);
}
