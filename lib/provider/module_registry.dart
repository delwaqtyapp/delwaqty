import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/customer/splash/splash_module.dart';
import 'package:delwaqty/features/customer/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/complaints/complaints_module.dart';
import 'package:delwaqty/features/customer/settings/settings_module.dart';
import 'package:delwaqty/features/customer/profile/profile_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/_shared/rewards/rewards_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/financial/financial_module.dart';
import 'package:delwaqty/features/customer/delivery/delivery_module.dart';
import 'package:delwaqty/features/customer/wallet/wallet_module.dart';

void registerProviderModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    SplashModule(),
    OnboardingModule(),
    WelcomeModule(),
    AuthModule(),
    RegionsModule(),
    ComplaintsModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    RewardsModule(),
    CampaignsModule(),
    CommerceModule(),
    RestaurantModule(),
    MerchantModule(),
    FinancialModule(),
    DirectDeliveryModule(),
    WalletModule(),
  ]);

  registry.freeze();
}
