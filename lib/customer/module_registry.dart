import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/customer/splash/splash_module.dart';
import 'package:delwaqty/features/customer/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/customer/home/home_module.dart';
import 'package:delwaqty/features/customer/settings/settings_module.dart';
import 'package:delwaqty/features/customer/profile/profile_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/customer/wallet/wallet_module.dart';
import 'package:delwaqty/features/customer/delivery/delivery_module.dart';
import 'package:delwaqty/features/customer/search/search_module.dart';
import 'package:delwaqty/features/customer/orders/orders_module.dart';
import 'package:delwaqty/features/customer/home_services/home_services_module.dart';
import 'package:delwaqty/features/_shared/complaints/complaints_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/rewards/rewards_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/admin/support_chat/support_chat_module.dart';

void registerAllModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    SplashModule(),
    OnboardingModule(),
    WelcomeModule(),
    AuthModule(),
    HomeModule(),
    CommerceModule(),
    RestaurantModule(),
    WalletModule(),
    DirectDeliveryModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    HomeServicesModule(),
    ComplaintsModule(),
    SupportChatModule(),
    SearchModule(),
    OrdersModule(),
    RegionsModule(),
    RewardsModule(),
    CampaignsModule(),
  ]);

  registry.freeze();
}
