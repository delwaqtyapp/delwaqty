import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/splash/splash_module.dart';
import 'package:delwaqty/features/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/welcome/welcome_module.dart';
import 'package:delwaqty/features/auth/auth_module.dart';
import 'package:delwaqty/features/home/home_module.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/features/settings/settings_module.dart';
import 'package:delwaqty/features/profile/profile_module.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';

void registerAllModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    SplashModule(),
    OnboardingModule(),
    WelcomeModule(),
    AuthModule(),
    HomeModule(),
    ExpensesModule(),
    CommerceModule(),
    RestaurantModule(),
    SettingsModule(),
    ProfileModule(),
    NotificationsModule(),
    AdminModule(),
  ]);

  registry.freeze();
}
