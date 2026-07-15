import 'package:delwaqty/features/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/commerce/domain/repositories/coupon_repository.dart';

class MockCouponRepository implements CouponRepository {
  final List<Coupon> _coupons;

  MockCouponRepository() : _coupons = _sampleCoupons();

  @override
  Future<List<Coupon>> getAvailableCoupons() async =>
      _coupons.where((c) => c.isActive).toList();

  @override
  Future<Coupon?> getCouponByCode(String code) async {
    try {
      return _coupons.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Coupon?> validateCoupon(String code, double orderTotal) async {
    final coupon = await getCouponByCode(code);
    if (coupon == null || !coupon.isActive) return null;
    if (coupon.minimumOrder != null && orderTotal < coupon.minimumOrder!) {
      return null;
    }
    if (coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now())) {
      return null;
    }
    return coupon;
  }
}

List<Coupon> _sampleCoupons() => [
      Coupon(
        id: 'coupon_1',
        code: 'SAVE10',
        type: CouponType.percentage,
        value: 10,
        minimumOrder: 30,
        maximumDiscount: 50,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
      Coupon(
        id: 'coupon_2',
        code: 'FREEDEL',
        type: CouponType.freeDelivery,
        value: 0,
        minimumOrder: 50,
        expiresAt: DateTime.now().add(const Duration(days: 14)),
      ),
      Coupon(
        id: 'coupon_3',
        code: 'WELCOME20',
        type: CouponType.percentage,
        value: 20,
        minimumOrder: 50,
        maximumDiscount: 100,
        expiresAt: DateTime.now().add(const Duration(days: 60)),
      ),
    ];
