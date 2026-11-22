import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/customer/splash/splash_module.dart';
import 'package:delwaqty/features/customer/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/customer/settings/settings_module.dart';
import 'package:delwaqty/features/customer/profile/profile_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/features/provider/financial/financial_module.dart';
import 'package:delwaqty/features/admin/support_chat/support_chat_module.dart';

// Provider flavor: customer-only modules (complaints, rewards, direct
// delivery, customer wallet) are intentionally NOT registered. The provider
// money surface is the financial center; owner review 2026-11-22 asked for
// one entry per function and no customer features in the provider app.
void registerProviderModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    SplashModule(),
    OnboardingModule(),
    WelcomeModule(),
    AuthModule(),
    RegionsModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    CampaignsModule(),
    CommerceModule(),
    RestaurantModule(),
    MerchantModule(),
    ProviderOrdersNavModule(),
    ProviderProductsNavModule(),
    FinancialModule(),
    SupportChatModule(),
  ]);

  registry.freeze();
}
