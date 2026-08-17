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
import 'package:delwaqty/features/orders/orders_module.dart';
import 'package:delwaqty/features/service_audio_logs/service_audio_logs_module.dart';
import 'package:delwaqty/features/complaints/complaints_module.dart';
import 'package:delwaqty/features/sanctions/sanctions_module.dart';
import 'package:delwaqty/features/location_tracking/location_tracking_module.dart';
import 'package:delwaqty/features/support_chat/support_chat_module.dart';
import 'package:delwaqty/features/home_services/home_services_module.dart';
import 'package:delwaqty/features/regions/regions_module.dart';
import 'package:delwaqty/features/rewards/rewards_module.dart';
import 'package:delwaqty/features/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/escalation/escalation_module.dart';
import 'package:delwaqty/features/member_management/member_management_module.dart';

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
    ServiceAudioLogsModule(),
    ComplaintsModule(),
    SanctionsModule(),
    LocationTrackingModule(),
    SupportChatModule(),
    SearchModule(),
    OrdersModule(),
    HomeServicesModule(),
    RegionsModule(),
    RewardsModule(),
    CampaignsModule(),
    MemberManagementModule(),
    EscalationModule(),
  ]);

  registry.freeze();
}
