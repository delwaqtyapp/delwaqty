import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/features/_shared/auth/auth_module.dart';
import 'package:delwaqty/features/customer/welcome/welcome_module.dart';
import 'package:delwaqty/features/admin/admin_module.dart';
import 'package:delwaqty/features/admin/member_management/member_management_module.dart';
import 'package:delwaqty/features/admin/sanctions/sanctions_module.dart';
import 'package:delwaqty/features/admin/location_tracking/location_tracking_module.dart';
import 'package:delwaqty/features/admin/support_chat/support_chat_module.dart';
import 'package:delwaqty/features/admin/escalation/escalation_module.dart';
import 'package:delwaqty/features/_shared/regions/regions_module.dart';
import 'package:delwaqty/features/_shared/campaigns/campaigns_module.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';

// Admin flavor: customer-facing complaints (/my-complaints, /new-complaint)
// and rewards (/rewards) are intentionally NOT registered. Complaint handling
// lives at /admin/complaints; the route resolver never maps admin taps to
// customer routes, and the channels table scopes /rewards to the customer
// app (owner rule: no customer features outside the customer app).
void registerAdminModules() {
  final registry = FeatureRegistry.instance;

  registry.registerAll([
    AuthModule(),
    WelcomeModule(),
    AdminModule(),
    MemberManagementModule(),
    SanctionsModule(),
    LocationTrackingModule(),
    SupportChatModule(),
    EscalationModule(),
    RegionsModule(),
    CampaignsModule(),
    NotificationsModule(),
  ]);

  registry.freeze();
}
