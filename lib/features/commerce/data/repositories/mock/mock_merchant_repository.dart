import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/domain/entities/search_filter.dart';
import 'package:delwaqty/features/commerce/domain/repositories/merchant_repository.dart';

class MockMerchantRepository implements MerchantRepository {
  final List<Merchant> _merchants;

  MockMerchantRepository() : _merchants = _sampleMerchants();

  @override
  Future<List<Merchant>> getMerchants({
    MerchantType? type,
    String? city,
    bool? isOpenNow,
    SearchFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    var results = List<Merchant>.from(_merchants);
    if (type != null) results = results.where((m) => m.type == type).toList();
    if (city != null) {
      results = results.where((m) => m.city == city).toList();
    }
    if (isOpenNow != null) {
      results = results.where((m) => m.isOpenNow == isOpenNow).toList();
    }
    if (filter?.minRating != null) {
      results = results.where((m) => m.rating >= filter!.minRating!).toList();
    }
    return results.skip(offset).take(limit).toList();
  }

  @override
  Future<Merchant?> getMerchantById(String id) async {
    try {
      return _merchants.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Merchant>> getFeaturedMerchants() async =>
      _merchants.where((m) => m.isFeatured).toList();

  @override
  Future<List<Merchant>> searchMerchants(String query) async {
    final q = query.toLowerCase();
    return _merchants
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<List<Merchant>> getMerchantsByType(MerchantType type) async =>
      _merchants.where((m) => m.type == type).toList();
}

List<Merchant> _sampleMerchants() => [
  Merchant(
    id: 'm1',
    name: 'Al Baik',
    type: MerchantType.restaurant,
    latitude: 24.7136,
    longitude: 46.6753,
    address: 'Olaya St, Riyadh',
    city: 'Riyadh',
    rating: 4.5,
    ratingCount: 1250,
    imageUrl: 'https://picsum.photos/seed/albaik/200',
    description: 'Famous fried chicken restaurant',
    isOpenNow: true,
    isVerified: true,
    isFeatured: true,
    deliveryAvailable: true,
    pickupAvailable: true,
    estimatedDeliveryMinutes: 30,
    deliveryFee: 10.0,
    minimumOrder: 25.0,
    tags: ['chicken', 'fast food', 'local favorite'],
    createdAt: DateTime(2023, 1, 1),
  ),
  Merchant(
    id: 'm2',
    name: 'Tamimi Markets',
    type: MerchantType.grocery,
    latitude: 24.7200,
    longitude: 46.6800,
    address: 'King Fahd Rd, Riyadh',
    city: 'Riyadh',
    rating: 4.3,
    ratingCount: 800,
    imageUrl: 'https://picsum.photos/seed/tamimi/200',
    description: 'Premium grocery store',
    isOpenNow: true,
    isVerified: true,
    isFeatured: true,
    deliveryAvailable: true,
    pickupAvailable: false,
    estimatedDeliveryMinutes: 45,
    deliveryFee: 15.0,
    minimumOrder: 50.0,
    tags: ['grocery', 'fresh', 'organic'],
    createdAt: DateTime(2023, 2, 1),
  ),
  Merchant(
    id: 'm3',
    name: 'Nahdi Pharmacy',
    type: MerchantType.pharmacy,
    latitude: 24.7100,
    longitude: 46.6700,
    address: 'Exit 5, Riyadh',
    city: 'Riyadh',
    rating: 4.2,
    ratingCount: 600,
    imageUrl: 'https://picsum.photos/seed/nahdi/200',
    description: 'Largest pharmacy chain',
    isOpenNow: true,
    isVerified: true,
    isFeatured: false,
    deliveryAvailable: true,
    pickupAvailable: true,
    estimatedDeliveryMinutes: 20,
    deliveryFee: 5.0,
    minimumOrder: 15.0,
    tags: ['pharmacy', 'health', 'medicine'],
    createdAt: DateTime(2023, 3, 1),
  ),
  Merchant(
    id: 'm4',
    name: 'Jarir Bookstore',
    type: MerchantType.electronics,
    latitude: 24.7180,
    longitude: 46.6820,
    address: 'Olaya St, Riyadh',
    city: 'Riyadh',
    rating: 4.4,
    ratingCount: 1500,
    imageUrl: 'https://picsum.photos/seed/jarir/200',
    description: 'Books, electronics, and stationery',
    isOpenNow: true,
    isVerified: true,
    isFeatured: true,
    deliveryAvailable: true,
    pickupAvailable: true,
    estimatedDeliveryMinutes: 60,
    deliveryFee: 20.0,
    minimumOrder: 100.0,
    tags: ['electronics', 'books', 'stationery'],
    createdAt: DateTime(2023, 4, 1),
  ),
  Merchant(
    id: 'm5',
    name: 'IKEA',
    type: MerchantType.furniture,
    latitude: 24.7250,
    longitude: 46.6900,
    address: 'Exit 15, Riyadh',
    city: 'Riyadh',
    rating: 4.1,
    ratingCount: 900,
    imageUrl: 'https://picsum.photos/seed/ikea/200',
    description: 'Scandinavian furniture and home',
    isOpenNow: false,
    isVerified: true,
    isFeatured: true,
    deliveryAvailable: true,
    pickupAvailable: true,
    estimatedDeliveryMinutes: 120,
    deliveryFee: 50.0,
    minimumOrder: 200.0,
    tags: ['furniture', 'home', 'scandinavian'],
    createdAt: DateTime(2023, 5, 1),
  ),
];
