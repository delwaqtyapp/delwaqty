import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/admin/escalation/presentation/pages/admin_escalations_page.dart';
import 'package:delwaqty/features/admin/admin_shell.dart';
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
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: const ValueKey('AdminEscalationsPage-null'),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
        child: const AdminShell(child: AdminEscalationsPage()),
      ),
    ),
  ];
}
