import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/escalation/presentation/pages/admin_escalations_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class EscalationModule extends FeatureModule {
  @override
  String get id => 'escalation';

  @override
  String name(BuildContext context) =>
      AppLocalizations.of(context).escalationQueueTitle;

  @override
  IconData? get icon => Icons.swap_vert_circle_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 88;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/admin/escalations',
      builder: (context, state) => const AdminEscalationsPage(),
    ),
  ];
}
