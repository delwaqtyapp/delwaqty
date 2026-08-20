import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/features/customer/restaurant/data/datasources/remote/supabase_offer_data_source.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/offer_repository.dart';

class OfferRepositoryImpl implements OfferRepository {
  OfferRepositoryImpl(this._dataSource);
  final SupabaseOfferDataSource _dataSource;

  @override
  Future<List<Offer>> getOffers(String merchantId) async {
    try {
      return await _dataSource.getOffers(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Offer>> getBranchOffers(String branchId) async {
    try {
      return await _dataSource.getBranchOffers(branchId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Offer>> getCategoryOffers(String categoryId) async {
    try {
      return await _dataSource.getCategoryOffers(categoryId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Offer>> getAutomaticOffers(String merchantId) async {
    try {
      return await _dataSource.getAutomaticOffers(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Offer>> getActiveOffers(String merchantId) async {
    try {
      return await _dataSource.getActiveOffers(merchantId);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Offer?> getOfferById(String id) async {
    try {
      return await _dataSource.getOfferById(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Offer> createOffer(Offer offer) async {
    try {
      return await _dataSource.createOffer(offer);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Offer> updateOffer(Offer offer) async {
    try {
      return await _dataSource.updateOffer(offer);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteOffer(String id) async {
    try {
      await _dataSource.deleteOffer(id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<double> calculateDiscount(
    String offerId,
    double orderTotal,
    List<String> productIds,
  ) async {
    try {
      final offer = await getOfferById(offerId);
      if (offer == null) return 0;
      return _dataSource.calculateDiscount(offer, orderTotal, productIds);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
