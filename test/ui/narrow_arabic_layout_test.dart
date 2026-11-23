import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_review.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_booking.dart';
import 'package:delwaqty/features/customer/home_services/domain/repositories/service_booking_repository.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/service_booking_page.dart';
import 'package:delwaqty/features/customer/home_services/presentation/pages/service_reviews_page.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/order.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/order_repository.dart';
import 'package:delwaqty/features/customer/commerce/presentation/pages/order_tracking_page.dart';
import 'package:delwaqty/features/customer/commerce/presentation/pages/orders_page.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_profile.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/branch_repository.dart';
import 'package:delwaqty/features/customer/restaurant/domain/repositories/reservation_repository.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/pages/restaurant_reservation_page.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/driver/presentation/pages/driver_delivery_detail_page.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_order.dart';
import 'package:delwaqty/features/provider/merchant/domain/entities/merchant_stats.dart';
import 'package:delwaqty/features/provider/merchant/domain/repositories/merchant_dashboard_repository.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_orders_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/review_repository.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/pages/restaurant_reviews_page.dart';
import 'package:delwaqty/features/provider/verification/presentation/pages/provider_verification_page.dart';
import 'package:delwaqty/features/provider/verification/presentation/providers/provider_verification_providers.dart';
import 'package:delwaqty/features/provider/documents/presentation/pages/provider_documents_page.dart';
import 'package:delwaqty/features/provider/documents/presentation/providers/provider_documents_providers.dart';
import 'package:delwaqty/features/provider/financial/presentation/pages/financial_center_page.dart';
import 'package:delwaqty/features/provider/financial/presentation/providers/financial_providers.dart';
import 'package:delwaqty/features/provider/financial/domain/entities/financial_entities.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_audit_log_page.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_drivers_page.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_models.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_provider_intelligence_page.dart';
import 'package:delwaqty/features/admin/presentation/providers/platform_intelligence_providers.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/features/admin/presentation/widgets/intelligence_stat_grid.dart';
import 'package:delwaqty/features/admin/domain/entities/platform_intelligence.dart';

/// Regression tests for the narrow-width / large-text-scale UI batch.
/// Every page is pumped at 320x640 logical pixels with an Arabic locale and
/// a 1.6 text scale, populated with realistic fixtures. RenderFlex overflow
/// throws inside widget tests, so `takeException() == null` plus content
/// assertions prove the layout survives.
void main() {
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'));
    await font.load();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(fontFamily: 'Cairo'),
            home: home,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Pages with repeating pulse animations never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  _registerOrderPageTests(pumpPage);
  _registerMerchantOrdersTest(pumpPage);
  _registerDriverDeliveryDetailTest(pumpPage);
  _registerReservationTest(pumpPage);

  group('ServiceReviewsPage SummaryCard histogram', () {
    testWidgets('320 / 1.6x Arabic: no overflow, 1000 stays on one line', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: SummaryCard(
              summary: ServiceReviewSummary(
                averageRating: 4.8,
                totalReviews: 1234,
                fiveStar: 1000,
                fourStar: 200,
                threeStar: 20,
                twoStar: 9,
                oneStar: 5,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final count = find.text('1000');
      expect(count, findsOneWidget);
      final size = tester.getSize(count);
      expect(size.width, greaterThan(size.height));
    });
  });

  group('RestaurantReviewsPage histogram', () {
    testWidgets('320 / 1.6x Arabic: no overflow, 1000 stays on one line', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const RestaurantReviewsPage(merchantId: 'm1'),
        overrides: [
          reviewRepositoryProvider.overrideWithValue(_FakeReviewRepository()),
        ],
      );
      expect(tester.takeException(), isNull);
      final count = find.text('1000');
      expect(count, findsOneWidget);
      final size = tester.getSize(count);
      expect(size.width, greaterThan(size.height));
    });
  });

  group('ProviderVerificationPage rejected state', () {
    testWidgets('rejected shows one card with reason, never "not submitted"', (
      tester,
    ) async {
      const reason = 'صورة البطاقة غير واضحة، يرجى إعادة التصوير بإضاءة جيدة';
      await pumpPage(
        tester,
        const ProviderVerificationPage(),
        overrides: [
          providerVerificationProvider.overrideWith(
            (ref) async => <String, dynamic>{
              'verification_status': 'rejected',
              'rejection_reason': reason,
              'id_card_url': 'private/id.jpg',
              'profile_photo_url': 'private/photo.jpg',
            },
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      // The grey "not submitted" card must not accompany a rejection.
      expect(find.byIcon(Icons.hourglass_top), findsNothing);
    });
  });

  group('ProviderDocumentsPage actions', () {
    testWidgets('320 / 1.6x Arabic: title and reason keep full width', (
      tester,
    ) async {
      const reason = 'المستند منتهي الصلاحية ويحتاج إلى نسخة حديثة واضحة';
      await pumpPage(
        tester,
        const ProviderDocumentsPage(),
        overrides: [
          providerDocumentsProvider.overrideWith(
            (ref) async => <Map<String, dynamic>>[
              {
                'doc_type': 'identity',
                'status': 'rejected',
                'rejection_reason': reason,
                'file_url': 'private/identity.jpg',
              },
              {
                'doc_type': 'license',
                'status': 'pending',
                'file_url': 'private/license.jpg',
              },
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining(reason), findsOneWidget);
    });
  });

  group('FinancialCenterPage recent transactions', () {
    testWidgets('320 / 1.6x Arabic: amount drops under the description', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const FinancialCenterPage(),
        overrides: [
          financialSummaryProvider.overrideWith(
            (ref) async => FinancialSummary(
              balance: 370.5,
              graceLimit: 500,
              graceUsed: 100,
              graceRemaining: 400,
              commissionRate: 0.1,
              pendingTopups: 0,
              recentTransactions: [
                WalletTransaction(
                  id: 't1',
                  type: 'credit',
                  amount: 1234.5,
                  description: 'شحن رصيد المحفظة عن طريق تحويل فودافون كاش رقم مرجعي طويل',
                  balanceAfter: 1605,
                  createdAt: DateTime(2026, 11, 20),
                ),
                WalletTransaction(
                  id: 't2',
                  type: 'debit',
                  amount: 25,
                  description: 'عمولة الطلب رقم 98765 من عميل التجمع الخامس',
                  balanceAfter: 370.5,
                  createdAt: DateTime(2026, 11, 21),
                ),
              ],
            ),
          ),
          graceProvider.overrideWith(
            (ref) async =>
                const GraceInfo(limit: 500, used: 100, remaining: 400),
          ),
          topupRequestsProvider.overrideWith((ref) async => <TopupRequest>[]),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('1234.50'), findsOneWidget);
    });
  });

  group('ServiceBookingPage provider selector', () {
    testWidgets('320 / 1.6x Arabic: card height is content-driven', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ServiceBookingPage(categoryType: ServiceCategoryType.plumbing),
        overrides: [
          serviceBookingRepositoryProvider.overrideWithValue(
            _FakeBookingRepository(),
          ),
          userLocationProvider.overrideWith(_FakeUserLocationNotifier.new),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('محمد أحمد عبدالله السيد'), findsOneWidget);
    });
  });

  group('AdminDriversPage driver card', () {
    testWidgets('320 / 1.6x Arabic: metric chips wrap, no right overflow', (
      tester,
    ) async {
      await pumpPage(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Builder(
              builder: (context) => AdminDriverGlassTile(
                driver: const {
                  'name': 'أحمد محمد عبدالله',
                  'phone': '01000000000',
                  'is_active': true,
                  'verification_status': 'pending',
                  'rating': 4.8,
                  'trips_count': 1234,
                  'vehicle': {'model': 'دراجة نارية', 'plate': 'أ ب ج 1234'},
                },
                cs: Theme.of(context).colorScheme,
                l10n: AppLocalizations.of(context),
                onVerify: () {},
                onSuspend: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('أحمد محمد عبدالله'), findsOneWidget);
    });
  });

  group('AdminProviderIntelligencePage summary cards', () {
    testWidgets(
      '320 / 1.6x Arabic: flexible heights, localized category chips',
      (tester) async {
        await pumpPage(
          tester,
          const AdminProviderIntelligencePage(),
          overrides: [
            providerIntelligenceProvider.overrideWith(
              (ref) async => const ProviderIntelligence(
                totalProviders: 1234,
                verifiedProviders: 1000,
                availableProviders: 999,
                providersByCategory: [TypeCount(type: 'plumbing', count: 1234)],
                bookingsByCategory: [TypeCount(type: 'plumbing', count: 1234)],
              ),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        // Raw backend type must be localized.
        expect(find.text('سباكة'), findsNWidgets(2));
        expect(find.text('plumbing'), findsNothing);
      },
    );
  });

  group('IntelligenceStatGrid shared widget', () {
    testWidgets('320 / 1.6x Arabic: long labels never overflow', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: IntelligenceStatGrid(
              wideColumns: 4,
              stats: [
                IntelligenceStat(
                  title: 'إجمالي المبالغ المستحقة',
                  value: 'ج.م 123457',
                  icon: Icons.savings_outlined,
                  color: Colors.green,
                ),
                IntelligenceStat(
                  title: 'المحافظ',
                  value: '12345',
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.purple,
                ),
                IntelligenceStat(
                  title: 'المعاملات',
                  value: '1234',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blue,
                ),
                IntelligenceStat(
                  title: 'الرصيد المتاح',
                  value: 'ج.م 1235',
                  icon: Icons.savings_outlined,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('12345'), findsOneWidget);
    });
  });

  group('AdminAuditLogPage resource label (item 72)', () {
    testWidgets('320 / 1.6x Arabic: known resource localizes, no raw code', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const AdminAuditLogPage(),
        overrides: [
          recentActivityProvider.overrideWith(
            (ref) async => [
              AdminActivityLog(
                id: 'log1',
                userId: 'admin1',
                action: 'commission_rate_updated',
                resource: 'service_category/plumbing',
                timestamp: DateTime(2026, 11, 20, 14, 30),
              ),
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      // Localized "Service category" in Arabic, never the raw code.
      expect(find.textContaining('فئة الخدمة'), findsOneWidget);
      expect(find.textContaining('service_category'), findsNothing);
    });
  });
}

class _FakeReviewRepository implements ReviewRepository {
  static const summary = ReviewSummary(
    averageRating: 4.8,
    totalReviews: 1234,
    fiveStarCount: 1000,
    fourStarCount: 200,
    threeStarCount: 20,
    twoStarCount: 9,
    oneStarCount: 5,
  );

  @override
  Future<List<Review>> getMerchantReviews(
    String merchantId, {
    int? limit,
    int? offset,
  }) async => [
    Review(
      id: 'r1',
      merchantId: merchantId,
      userId: 'u1',
      userName: 'محمد عبدالله',
      rating: 5,
      comment: 'خدمة ممتازة في الوصول وجودة الطعام كانت رائعة',
      createdAt: DateTime(2026, 11, 20),
    ),
  ];

  @override
  Future<ReviewSummary> getMerchantRatingSummary(String merchantId) async =>
      summary;

  @override
  Future<List<Review>> getProductReviews(
    String productId, {
    int? limit,
    int? offset,
  }) async => const [];

  @override
  Future<Review?> getReviewById(String id) async => null;

  @override
  Future<ReviewSummary> getProductRatingSummary(String productId) async =>
      summary;

  @override
  Future<Review> submitReview({
    required String merchantId,
    required String userId,
    String? productId,
    String? orderId,
    required double rating,
    String? comment,
    List<String>? imageUrls,
  }) => throw UnimplementedError();

  @override
  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {}

  @override
  Future<Review> updateReview({
    required String reviewId,
    double? rating,
    String? comment,
    List<String>? imageUrls,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteReview(String reviewId) async {}

  @override
  Stream<Review?> watchMerchantReviews(String merchantId) =>
      const Stream.empty();
}

class _FakeBookingRepository implements ServiceBookingRepository {
  static final providers = [
    ServiceProvider(
      id: 'p1',
      name: 'محمد أحمد عبدالله السيد',
      categoryType: ServiceCategoryType.plumbing,
      rating: 4.8,
      ratingCount: 1234,
      isVerified: true,
      isAvailable: true,
      createdAt: DateTime(2026, 1, 1),
    ),
    ServiceProvider(
      id: 'p2',
      name: 'محمود سيد',
      categoryType: ServiceCategoryType.plumbing,
      rating: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<ServiceProvider>> getProviders({
    ServiceCategoryType? categoryType,
    String? city,
  }) async => providers;

  @override
  Future<List<ServiceCategory>> getCategories() async => const [];

  @override
  Future<ServiceProvider?> getProvider(String id) async => providers.first;

  @override
  Future<List<ServiceBooking>> getUserBookings({String? userId}) async =>
      const [];

  @override
  Future<ServiceBooking?> getBooking(String id) async => null;

  @override
  Future<ServiceBooking> createBooking({
    required String userId,
    required String providerId,
    required String providerName,
    required ServiceCategoryType categoryType,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTime,
    required String address,
    double? addressLatitude,
    double? addressLongitude,
    double? estimatedPrice,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<ServiceBooking> updateBookingStatus(String id, BookingStatus status) =>
      throw UnimplementedError();

  @override
  Future<void> cancelBooking(String id) async {}
}

class _FakeUserLocationNotifier extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => null;
}

// ---------------------------------------------------------------------------
// Items 35/37: customer order tracking price rows + orders list status chips
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository({this.order, this.orders = const []});

  final Order? order;
  final List<Order> orders;

  @override
  Future<Order?> getOrderById(String id) async => order;

  @override
  Future<List<Order>> getOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async => orders;

  @override
  Future<Order> createOrder({
    required String merchantId,
    required String merchantName,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double total,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? paymentMethod,
    String? specialInstructions,
    String? couponCode,
    String? idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<Order> cancelOrder({required String orderId, String? reason}) =>
      throw UnimplementedError();
}

Order _trackingOrder() => Order(
  id: 'o1',
  merchantId: 'm1',
  merchantName: 'مطعم الاختبار',
  items: const [
    OrderItem(
      productId: 'p1',
      productName: 'وجبة دجاج مشوي مع أرز بسمتي وخضار مشكلة إضافية',
      quantity: 2,
      unitPrice: 1234.5,
      totalPrice: 2469.0,
    ),
  ],
  subtotal: 2469.0,
  deliveryFee: 25.0,
  total: 2494.0,
  status: OrderStatus.preparing,
  createdAt: DateTime(2026, 1, 1),
);

void _registerOrderPageTests(
  Future<void> Function(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides,
    bool settle,
  })
  pumpPage,
) {
  group('OrderTrackingPage price rows (item 35)', () {
    testWidgets('320 / 1.6x Arabic: amounts fully readable, no overflow', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const OrderTrackingPage(orderId: 'o1'),
        settle: false,
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FakeOrderRepository(order: _trackingOrder()),
          ),
          orderDeliveryRideProvider.overrideWith(
            (ref, orderId) => Stream<OrderDeliveryRide?>.value(null),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      // Full amount, never ellipsized.
      expect(find.textContaining('2469.00'), findsWidgets);
      expect(find.textContaining('2494.00'), findsWidgets);
    });
  });

  group('OrdersPage status chip (item 37)', () {
    testWidgets('320 / 1.6x Arabic: status chip gets its own line', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const OrdersPage(),
        settle: false,
        overrides: [
          orderRepositoryProvider.overrideWithValue(
            _FakeOrderRepository(orders: [_trackingOrder()]),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('مطعم الاختبار'), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------
// Item 34: merchant orders list rows
// ---------------------------------------------------------------------------

class _FakeMerchantDashboardRepository implements MerchantDashboardRepository {
  _FakeMerchantDashboardRepository({this.orders = const []});

  final List<MerchantOrder> orders;

  @override
  Future<List<MerchantOrder>> getMerchantOrders(
    String merchantId, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async => orders;

  @override
  Future<MerchantStats> getMerchantStats(String merchantId) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(String orderId, String status) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getMerchantProducts(String merchantId) =>
      throw UnimplementedError();

  @override
  Future<void> createProduct(String merchantId, Map<String, dynamic> product) =>
      throw UnimplementedError();

  @override
  Future<void> updateProduct(String productId, Map<String, dynamic> product) =>
      throw UnimplementedError();

  @override
  Future<void> deleteProduct(String productId) => throw UnimplementedError();
}

void _registerMerchantOrdersTest(
  Future<void> Function(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides,
    bool settle,
  })
  pumpPage,
) {
  group('MerchantOrdersPage rows (item 34)', () {
    testWidgets('320 / 1.6x Arabic: amount on own line, actions wrap', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const MerchantOrdersPage(),
        settle: false,
        overrides: [
          merchantDashboardRepositoryProvider.overrideWithValue(
            _FakeMerchantDashboardRepository(
              orders: [
                MerchantOrder(
                  id: 'mo1',
                  customerId: 'c1',
                  customerName: 'أحمد محمد عبدالله إبراهيم',
                  totalAmount: 12345.67,
                  status: 'pending',
                  createdAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
          ),
          // Empty id skips the realtime subscription in initState.
          providerMerchantIdProvider.overrideWith((ref) async => ''),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('12345.67'), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------
// Item 47: driver delivery detail stacked rows + localized fare
// ---------------------------------------------------------------------------

class _FakeAuthenticatedNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(
    user: User(
      id: 'd1',
      email: 'driver@example.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
}

void _registerDriverDeliveryDetailTest(
  Future<void> Function(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides,
    bool settle,
  })
  pumpPage,
) {
  group('DriverDeliveryDetailPage fare rows (item 47)', () {
    testWidgets('320 / 1.6x Arabic: fare readable, no overflow', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const DriverDeliveryDetailPage(id: 'del1'),
        settle: false,
        overrides: [
          authStateProvider.overrideWith(_FakeAuthenticatedNotifier.new),
          deliveryOrderByIdProvider.overrideWith(
            (ref, id) async => DeliveryOrder(
              id: 'del1',
              serviceType: 'delivery',
              pickupLatitude: 30.0,
              pickupLongitude: 31.0,
              dropoffLatitude: 30.1,
              dropoffLongitude: 31.1,
              pickupAddress: 'عنوان الاستلام من المتجر الكبير',
              dropoffAddress: 'عنوان التوصيل إلى العميل',
              fare: 1234.56,
              status: 'in_progress',
            ),
          ),
          driverProfileProvider.overrideWith(
            (ref, id) async => DriverProfile(
              id: 'dr1',
              userId: 'd1',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
          driverLivePositionProvider.overrideWith((ref, id) => null),
          cashCollectionStateProvider.overrideWith((ref, id) async => null),
        ],
      );
      expect(tester.takeException(), isNull);
      // Fare renders whole (toStringAsFixed(0)) with the localized
      // currency symbol.
      expect(find.textContaining('1235'), findsWidgets);
      expect(find.textContaining('ج.م'), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------
// Item 42: restaurant reservation date chips + slots
// ---------------------------------------------------------------------------

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> getBranches(String merchantId) async => [
    Branch(
      id: 'b1',
      merchantId: 'm1',
      name: 'الفرع الرئيسي',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<Branch?> getBranchById(String id) async => null;

  @override
  Future<Branch> createBranch(Branch branch) => throw UnimplementedError();

  @override
  Future<Branch> updateBranch(Branch branch) => throw UnimplementedError();

  @override
  Future<void> deleteBranch(String id) => throw UnimplementedError();
}

class _FakeReservationRepository implements ReservationRepository {
  @override
  Future<List<ReservationSlot>> getAvailableSlots({
    required String merchantId,
    required DateTime date,
    required int partySize,
    String? branchId,
  }) async => [
    ReservationSlot(
      time: date,
      tableNumber: 'T1',
      capacity: 4,
      isAvailable: true,
    ),
  ];

  @override
  Future<List<Reservation>> getReservations(
    String merchantId, {
    ReservationStatus? status,
  }) async => const [];

  @override
  Future<List<Reservation>> getUserReservations(
    String userId, {
    ReservationStatus? status,
  }) async => const [];

  @override
  Future<Reservation?> getReservationById(String id) async => null;

  @override
  Future<Reservation> createReservation(Reservation reservation) =>
      throw UnimplementedError();

  @override
  Future<Reservation> updateReservation(String id, ReservationStatus status) =>
      throw UnimplementedError();

  @override
  Future<Reservation> modifyReservation({
    required String reservationId,
    int? partySize,
    DateTime? reservationTime,
    String? specialRequests,
    String? tableNumber,
  }) => throw UnimplementedError();

  @override
  Future<Reservation> cancelReservation(
    String reservationId, {
    String? reason,
  }) => throw UnimplementedError();
}

void _registerReservationTest(
  Future<void> Function(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides,
    bool settle,
  })
  pumpPage,
) {
  group('RestaurantReservationPage date chips (item 42)', () {
    testWidgets('320 / 1.6x Arabic: date chips fully visible, no overflow', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const RestaurantReservationPage(merchantId: 'm1'),
        overrides: [
          branchRepositoryProvider.overrideWithValue(_FakeBranchRepository()),
          reservationRepositoryProvider.overrideWithValue(
            _FakeReservationRepository(),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });
}
