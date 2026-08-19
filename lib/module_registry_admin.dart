import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/auth/auth_module.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/member_management/member_management_module.dart';
import 'package:delwaqty/features/complaints/complaints_module.dart';
import 'package:delwaqty/features/sanctions/sanctions_module.dart';
import 'package:delwaqty/features/location_tracking/location_tracking_module.dart';
import 'package:delwaqty/features/support_chat/support_chat_module.dart';
import 'package:delwaqty/features/escalation/escalation_module.dart';
import 'package:delwaqty/features/regions/regions_module.dart';
import 'package:delwaqty/features/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/rewards/rewards_module.dart';
import 'package:delwaqty/features/notifications/notifications_module.dart';

void registerAdminModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    AuthModule(),
    AdminModule(),
    MemberManagementModule(),
    ComplaintsModule(),
    SanctionsModule(),
    LocationTrackingModule(),
    SupportChatModule(),
    EscalationModule(),
    RegionsModule(),
    CampaignsModule(),
    RewardsModule(),
    NotificationsModule(),
  ]);

  registry.freeze();
}
