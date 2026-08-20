import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/admin/member_management/member_management_module.dart';
import 'package:delwaqty/features/_shared/complaints/complaints_module.dart';
import 'package:delwaqty/features/admin/sanctions/sanctions_module.dart';
import 'package:delwaqty/features/admin/location_tracking/location_tracking_module.dart';
import 'package:delwaqty/features/admin/support_chat/support_chat_module.dart';
import 'package:delwaqty/features/admin/escalation/escalation_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/_shared/rewards/rewards_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';

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
