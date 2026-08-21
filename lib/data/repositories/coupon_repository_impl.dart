import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/data/datasources/remote/supabase_coupon_data_source.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/coupon_repository.dart';

class CouponRepositoryImpl implements CouponRepository {
  CouponRepositoryImpl(this._dataSource);
  final SupabaseCouponDataSource _dataSource;

  @override
  Future<List<Coupon>> getAvailableCoupons() async {
    try {
      return await _dataSource.getAvailableCoupons();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Coupon?> getCouponByCode(String code) async {
    try {
      return await _dataSource.getCouponByCode(code);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Coupon?> validateCoupon(String code, double orderTotal) async {
    try {
      return await _dataSource.validateCoupon(code, orderTotal);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Coupon> applyCoupon(String code, double orderTotal) async {
    try {
      final coupon = await _dataSource.validateCoupon(code, orderTotal);
      if (coupon == null) {
        throw const ServerException(message: 'Invalid or expired coupon');
      }
      await _dataSource.incrementUsage(code);
      return coupon;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Coupon>> getMerchantCoupons(String merchantId) async {
    try {
      return await _dataSource.getMerchantCoupons(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Coupon>> getBranchCoupons(String branchId) async {
    try {
      return await _dataSource.getBranchCoupons(branchId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Coupon>> getProductCoupons(String productId) async {
    try {
      return await _dataSource.getProductCoupons(productId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Coupon>> getCategoryCoupons(String categoryId) async {
    try {
      return await _dataSource.getCategoryCoupons(categoryId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<CouponStatus> getCouponStatus(String code) async {
    try {
      final coupon = await _dataSource.getCouponByCode(code);
      if (coupon == null) throw const ServerException(message: 'Coupon not found');
      return _dataSource.getCouponStatus(coupon);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
