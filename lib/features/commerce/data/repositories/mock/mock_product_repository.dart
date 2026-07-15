import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/repositories/product_repository.dart';

class MockProductRepository implements ProductRepository {
  final List<Product> _products;

  MockProductRepository() : _products = _sampleProducts();

  @override
  Future<List<Product>> getProducts({
    required String merchantId,
    String? categoryId,
    bool? isAvailable,
    int limit = 20,
    int offset = 0,
  }) async {
    var results = _products.where((p) => p.merchantId == merchantId).toList();
    if (categoryId != null) {
      results = results.where((p) => p.categoryId == categoryId).toList();
    }
    if (isAvailable != null) {
      results = results.where((p) => p.isAvailable == isAvailable).toList();
    }
    return results.skip(offset).take(limit).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Product>> getFeaturedProducts(String merchantId) async =>
      _products.where((p) => p.merchantId == merchantId && p.isFeatured).toList();

  @override
  Future<List<Product>> searchProducts(
    String query, {
    String? merchantId,
  }) async {
    final q = query.toLowerCase();
    var results = _products.where((p) {
      final matchesQuery =
          p.name.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      if (merchantId != null) {
        return matchesQuery && p.merchantId == merchantId;
      }
      return matchesQuery;
    }).toList();
    return results;
  }
}

List<Product> _sampleProducts() => [
      // Al Baik products
      Product(
        id: 'p1',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Meal',
        description: 'Signature crispy chicken with sides',
        price: 35.0,
        imageUrl: 'https://picsum.photos/seed/chicken/200',
        isAvailable: true,
        isFeatured: true,
        tags: ['chicken', 'meal', 'popular'],
        createdAt: DateTime(2023, 1, 1),
        variants: [
          ProductVariant(
              id: 'v1', productId: 'p1', name: 'Regular', price: 35.0),
          ProductVariant(
              id: 'v2', productId: 'p1', name: 'Large', price: 45.0),
          ProductVariant(
              id: 'v3', productId: 'p1', name: 'Family', price: 85.0),
        ],
      ),
      Product(
        id: 'p2',
        merchantId: 'm1',
        categoryId: 'c1',
        name: 'Chicken Sandwich',
        description: 'Crispy chicken in a fresh bun',
        price: 20.0,
        imageUrl: 'https://picsum.photos/seed/sandwich/200',
        isAvailable: true,
        isFeatured: false,
        tags: ['chicken', 'sandwich'],
        createdAt: DateTime(2023, 1, 1),
      ),
      Product(
        id: 'p3',
        merchantId: 'm1',
        categoryId: 'c2',
        name: 'Fries',
        description: 'Golden crispy fries',
        price: 10.0,
        imageUrl: 'https://picsum.photos/seed/fries/200',
        isAvailable: true,
        isFeatured: false,
        tags: ['fries', 'side'],
        createdAt: DateTime(2023, 1, 1),
      ),
      // Tamimi products
      Product(
        id: 'p4',
        merchantId: 'm2',
        categoryId: 'c3',
        name: 'Fresh Milk 2L',
        description: 'Full cream fresh milk',
        price: 12.5,
        imageUrl: 'https://picsum.photos/seed/milk/200',
        isAvailable: true,
        isFeatured: true,
        tags: ['milk', 'dairy', 'fresh'],
        createdAt: DateTime(2023, 2, 1),
      ),
      Product(
        id: 'p5',
        merchantId: 'm2',
        categoryId: 'c3',
        name: 'Bread Loaf',
        description: 'Whole wheat bread',
        price: 6.0,
        imageUrl: 'https://picsum.photos/seed/bread/200',
        isAvailable: true,
        isFeatured: false,
        tags: ['bread', 'bakery'],
        createdAt: DateTime(2023, 2, 1),
      ),
      Product(
        id: 'p6',
        merchantId: 'm2',
        categoryId: 'c4',
        name: 'Bananas 1kg',
        description: 'Fresh bananas',
        price: 8.0,
        originalPrice: 10.0,
        imageUrl: 'https://picsum.photos/seed/banana/200',
        isAvailable: true,
        isFeatured: true,
        tags: ['fruit', 'fresh', 'organic'],
        createdAt: DateTime(2023, 2, 1),
      ),
      // Nahdi products
      Product(
        id: 'p7',
        merchantId: 'm3',
        categoryId: 'c5',
        name: 'Paracetamol 500mg',
        description: 'Pain relief tablets',
        price: 15.0,
        imageUrl: 'https://picsum.photos/seed/paracetamol/200',
        isAvailable: true,
        isFeatured: true,
        tags: ['medicine', 'pain relief'],
        createdAt: DateTime(2023, 3, 1),
      ),
      Product(
        id: 'p8',
        merchantId: 'm3',
        categoryId: 'c5',
        name: 'Vitamin C 1000mg',
        description: 'Immune support supplement',
        price: 45.0,
        imageUrl: 'https://picsum.photos/seed/vitaminc/200',
        isAvailable: true,
        isFeatured: false,
        tags: ['vitamin', 'supplement', 'health'],
        createdAt: DateTime(2023, 3, 1),
      ),
    ];
