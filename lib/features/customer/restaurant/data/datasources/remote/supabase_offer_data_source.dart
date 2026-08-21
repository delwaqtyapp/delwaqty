import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/offer.dart';

final supabaseOfferDataSourceProvider = Provider<SupabaseOfferDataSource>((
  ref,
) {
  return SupabaseOfferDataSource(ref.watch(supabaseClientProvider));
});

class SupabaseOfferDataSource {
  SupabaseOfferDataSource(this._client);
  final SupabaseClient _client;

  Offer _fromRow(Map<String, dynamic> row) => Offer(
    id: row['id'] as String,
    merchantId: row['merchant_id'] as String,
    branchId: row['branch_id'] as String?,
    categoryId: row['category_id'] as String?,
    title: row['title'] as String,
    description: row['description'] as String?,
    discountType: row['discount_type'] as String? ?? 'percentage',
    discountValue: (row['discount_value'] as num).toDouble(),
    minimumOrder: (row['minimum_order'] as num? ?? 0).toDouble(),
    maximumDiscount: row['maximum_discount'] != null
        ? (row['maximum_discount'] as num).toDouble()
        : null,
    productIds: row['product_ids'] != null
        ? List<String>.from(row['product_ids'] as List)
        : [],
    isActive: row['is_active'] as bool? ?? true,
    isAutomatic: row['is_automatic'] as bool? ?? false,
    startsAt: row['starts_at'] != null
        ? DateTime.parse(row['starts_at'] as String)
        : null,
    expiresAt: row['expires_at'] != null
        ? DateTime.parse(row['expires_at'] as String)
        : null,
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  bool _isActiveNow(Offer offer) {
    if (!offer.isActive) return false;
    final now = DateTime.now();
    if (offer.startsAt != null && offer.startsAt!.isAfter(now)) return false;
    if (offer.expiresAt != null && offer.expiresAt!.isBefore(now)) return false;
    return true;
  }

  Future<List<Offer>> getOffers(String merchantId) async {
    final data = await _client
        .from('offers')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<Offer>> getActiveOffers(String merchantId) async {
    final all = await getOffers(merchantId);
    return all.where(_isActiveNow).toList();
  }

  Future<List<Offer>> getBranchOffers(String branchId) async {
    final data = await _client
        .from('offers')
        .select()
        .eq('branch_id', branchId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .where(_isActiveNow)
        .toList();
  }

  Future<List<Offer>> getCategoryOffers(String categoryId) async {
    final data = await _client
        .from('offers')
        .select()
        .eq('category_id', categoryId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .where(_isActiveNow)
        .toList();
  }

  Future<List<Offer>> getAutomaticOffers(String merchantId) async {
    final data = await _client
        .from('offers')
        .select()
        .eq('merchant_id', merchantId)
        .eq('is_automatic', true)
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => _fromRow(r as Map<String, dynamic>))
        .where(_isActiveNow)
        .toList();
  }

  Future<Offer?> getOfferById(String id) async {
    final data = await _client
        .from('offers')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? _fromRow(data) : null;
  }

  Future<Offer> createOffer(Offer offer) async {
    final data = await _client
        .from('offers')
        .insert({
          'merchant_id': offer.merchantId,
          'branch_id': offer.branchId,
          'category_id': offer.categoryId,
          'title': offer.title,
          'description': offer.description,
          'discount_type': offer.discountType,
          'discount_value': offer.discountValue,
          'minimum_order': offer.minimumOrder,
          'maximum_discount': offer.maximumDiscount,
          'product_ids': offer.productIds,
          'is_active': offer.isActive,
          'is_automatic': offer.isAutomatic,
          'starts_at': offer.startsAt?.toIso8601String(),
          'expires_at': offer.expiresAt?.toIso8601String(),
        })
        .select()
        .single();
    return _fromRow(data);
  }

  Future<Offer> updateOffer(Offer offer) async {
    final data = await _client
        .from('offers')
        .update({
          'branch_id': offer.branchId,
          'category_id': offer.categoryId,
          'title': offer.title,
          'description': offer.description,
          'discount_type': offer.discountType,
          'discount_value': offer.discountValue,
          'minimum_order': offer.minimumOrder,
          'maximum_discount': offer.maximumDiscount,
          'product_ids': offer.productIds,
          'is_active': offer.isActive,
          'is_automatic': offer.isAutomatic,
          'starts_at': offer.startsAt?.toIso8601String(),
          'expires_at': offer.expiresAt?.toIso8601String(),
        })
        .eq('id', offer.id)
        .select()
        .single();
    return _fromRow(data);
  }

  Future<void> deleteOffer(String id) async {
    await _client.from('offers').delete().eq('id', id);
  }

  double calculateDiscount(
    Offer offer,
    double orderTotal,
    List<String> productIds,
  ) {
    if (!_isActiveNow(offer)) return 0;
    if (offer.minimumOrder > 0 && orderTotal < offer.minimumOrder) return 0;
    double discount = 0;
    if (offer.discountType == 'percentage') {
      discount = orderTotal * (offer.discountValue / 100);
    } else if (offer.discountType == 'fixed') {
      discount = offer.discountValue;
    } else if (offer.discountType == 'bogo') {
      final matchingProducts = productIds
          .where((id) => offer.productIds.contains(id))
          .length;
      discount = orderTotal * (matchingProducts * 0.5).clamp(0.0, 0.5);
    }
    if (offer.maximumDiscount != null && discount > offer.maximumDiscount!) {
      discount = offer.maximumDiscount!;
    }
    return discount;
  }
}
