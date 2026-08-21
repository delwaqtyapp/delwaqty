import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/_shared/complaints/presentation/pages/my_complaints_page.dart';
import 'package:delwaqty/features/_shared/complaints/presentation/pages/new_complaint_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ComplaintsModule extends FeatureModule {
  @override
  String get id => 'complaints';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).complaints;

  @override
  IconData? get icon => Icons.warning_amber_rounded;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 81;

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/my-complaints',
      builder: (context, state) => const MyComplaintsPage(),
    ),
    GoRoute(
      path: '/new-complaint',
      builder: (context, state) {
        final orderId = state.uri.queryParameters['orderId'];
        return NewComplaintPage(orderId: orderId);
      },
    ),
  ];
}
