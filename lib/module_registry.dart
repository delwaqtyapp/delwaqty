import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/splash/splash_module.dart';
import 'package:delwaqty/features/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/welcome/welcome_module.dart';
import 'package:delwaqty/features/auth/auth_module.dart';
import 'package:delwaqty/features/home/home_module.dart';
import 'package:delwaqty/features/settings/settings_module.dart';
import 'package:delwaqty/features/profile/profile_module.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/merchant/merchant_module.dart';
import 'package:delwaqty/features/wallet/wallet_module.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/ride/ride_module.dart';
import 'package:delwaqty/features/delivery/delivery_module.dart';
import 'package:delwaqty/features/safety/safety_module.dart';
import 'package:delwaqty/features/search/search_module.dart';

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
    RideModule(),
    DirectDeliveryModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    AdminModule(),
    SafetyModule(),
    SearchModule(),
  ]);

  registry.freeze();
}
