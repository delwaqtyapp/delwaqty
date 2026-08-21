import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/customer/splash/splash_module.dart';
import 'package:delwaqty/features/customer/onboarding/onboarding_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/customer/settings/settings_module.dart';
import 'package:delwaqty/features/customer/profile/profile_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/customer/safety/safety_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/complaints/complaints_module.dart';
import 'package:delwaqty/features/driver/driver_module.dart';

void registerDriverModules() {
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
    SafetyModule(),
    DriverModule(),
  ]);

  registry.freeze();
}
