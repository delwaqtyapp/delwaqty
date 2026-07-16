import 'package:delwaqty/features/restaurant/domain/entities/offer.dart';

abstract interface class OfferRepository {
  Future<List<Offer>> getOffers(String merchantId);
  Future<List<Offer>> getBranchOffers(String branchId);
  Future<List<Offer>> getCategoryOffers(String categoryId);
  Future<List<Offer>> getAutomaticOffers(String merchantId);
  Future<List<Offer>> getActiveOffers(String merchantId);
  Future<Offer?> getOfferById(String id);
  Future<Offer> createOffer(Offer offer);
  Future<Offer> updateOffer(Offer offer);
  Future<void> deleteOffer(String id);
  Future<double> calculateDiscount(String offerId, double orderTotal, List<String> productIds);
}
