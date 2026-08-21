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
import 'package:delwaqty/features/customer/merchant/merchant_module.dart';
import 'package:delwaqty/features/customer/wallet/wallet_module.dart';
import 'package:delwaqty/features/customer/driver/driver_module.dart';
import 'package:delwaqty/features/customer/delivery/delivery_module.dart';
import 'package:delwaqty/features/customer/safety/safety_module.dart';
import 'package:delwaqty/features/customer/search/search_module.dart';
import 'package:delwaqty/features/customer/orders/orders_module.dart';
import 'package:delwaqty/features/customer/service_audio_logs/service_audio_logs_module.dart';
import 'package:delwaqty/features/_shared/complaints/complaints_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/rewards/rewards_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';

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
    MerchantModule(),
    WalletModule(),
    DriverModule(),
    DirectDeliveryModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    SafetyModule(),
    ServiceAudioLogsModule(),
    ComplaintsModule(),
    SearchModule(),
    OrdersModule(),
    RegionsModule(),
    RewardsModule(),
    CampaignsModule(),
  ]);

  registry.freeze();
}
