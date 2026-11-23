import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/customer/splash/splash_module.dart';
import 'package:delwaqty/features/customer/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/customer/settings/settings_module.dart';
import 'package:delwaqty/features/customer/profile/profile_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/admin/support_chat/support_chat_module.dart';
import 'package:delwaqty/features/_shared/suggestions/suggestions_module.dart';

// Driver flavor: customer complaints module intentionally NOT registered
// (owner route-audit rule: no customer features outside the customer app;
// support chat covers help). Suggestions IS registered in all four apps:
// owner request 2026-11-23 (platform-wide ideas next to Complaints), so it
// is not a customer-only feature.
void registerDriverModules() {
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
    DriverModule(),
    DriverHubNavModule(),
    DriverFinancialNavModule(),
    SuggestionsModule(),
    SupportChatModule(),
  ]);

  registry.freeze();
}
