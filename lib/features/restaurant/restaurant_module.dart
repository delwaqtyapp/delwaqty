import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_branch_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_working_hours_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_delivery_zone_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_modifier_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_restaurant_settings_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_offer_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_reservation_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_order_tracking_data_source.dart';
import 'package:delwaqty/features/restaurant/data/datasources/remote/supabase_inventory_data_source.dart';
import 'package:delwaqty/features/restaurant/data/repositories/branch_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/working_hours_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/delivery_zone_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/modifier_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/restaurant_settings_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/offer_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/reservation_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/order_tracking_repository_impl.dart';
import 'package:delwaqty/features/restaurant/data/repositories/inventory_repository_impl.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/branch_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/working_hours_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/delivery_zone_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/modifier_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/restaurant_settings_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/offer_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/reservation_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/order_tracking_repository.dart';
import 'package:delwaqty/features/restaurant/domain/repositories/inventory_repository.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_detail_page.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_menu_page.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_offers_page.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_reviews_page.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_reservation_page.dart';
import 'package:delwaqty/features/restaurant/presentation/pages/restaurant_order_tracking_page.dart';

final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepositoryImpl(ref.watch(supabaseBranchDataSourceProvider)),
);

final workingHoursRepositoryProvider = Provider<WorkingHoursRepository>(
  (ref) => WorkingHoursRepositoryImpl(
    ref.watch(supabaseWorkingHoursDataSourceProvider),
  ),
);

final deliveryZoneRepositoryProvider = Provider<DeliveryZoneRepository>(
  (ref) => DeliveryZoneRepositoryImpl(
    ref.watch(supabaseDeliveryZoneDataSourceProvider),
  ),
);

final modifierRepositoryProvider = Provider<ModifierRepository>(
  (ref) =>
      ModifierRepositoryImpl(ref.watch(supabaseModifierDataSourceProvider)),
);

final restaurantSettingsRepositoryProvider =
    Provider<RestaurantSettingsRepository>(
      (ref) => RestaurantSettingsRepositoryImpl(
        ref.watch(supabaseRestaurantSettingsDataSourceProvider),
      ),
    );

final offerRepositoryProvider = Provider<OfferRepository>(
  (ref) => OfferRepositoryImpl(ref.watch(supabaseOfferDataSourceProvider)),
);

final reservationRepositoryProvider = Provider<ReservationRepository>(
  (ref) => ReservationRepositoryImpl(
    ref.watch(supabaseReservationDataSourceProvider),
  ),
);

final orderTrackingRepositoryProvider = Provider<OrderTrackingRepository>(
  (ref) => OrderTrackingRepositoryImpl(
    ref.watch(supabaseOrderTrackingDataSourceProvider),
  ),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) =>
      InventoryRepositoryImpl(ref.watch(supabaseInventoryDataSourceProvider)),
);

class RestaurantModule extends FeatureModule {
  @override
  String get id => 'restaurant';

  @override
  String name(BuildContext context) => 'Restaurants';

  @override
  IconData? get icon => Icons.restaurant_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 10;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasDeepLinks};

  @override
  List<String> get dependsOn => ['commerce'];

  @override
  StatefulShellBranch? buildBranch() => null;

  @override
  List<RouteBase> get shellSubRoutes => [];

  @override
  List<RouteBase> get standaloneRoutes => [
        GoRoute(
          path: '/restaurant/:merchantId',
          builder: (context, state) => RestaurantDetailPage(
            merchantId: state.pathParameters['merchantId']!,
          ),
          routes: [
            GoRoute(
              path: 'menu',
              builder: (context, state) {
                final merchantId = state.pathParameters['merchantId']!;
                final merchantName = state.extra as String?;
                return RestaurantMenuPage(
                  merchantId: merchantId,
                  merchantName: merchantName,
                );
              },
            ),
            GoRoute(
              path: 'offers',
              builder: (context, state) => RestaurantOffersPage(
                merchantId: state.pathParameters['merchantId']!,
              ),
            ),
            GoRoute(
              path: 'reviews',
              builder: (context, state) => RestaurantReviewsPage(
                merchantId: state.pathParameters['merchantId']!,
              ),
            ),
            GoRoute(
              path: 'reservation',
              builder: (context, state) => RestaurantReservationPage(
                merchantId: state.pathParameters['merchantId']!,
              ),
            ),
            GoRoute(
              path: 'order-tracking/:orderId',
              builder: (context, state) => RestaurantOrderTrackingPage(
                orderId: state.pathParameters['orderId']!,
              ),
            ),
          ],
        ),
      ];

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
