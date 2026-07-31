import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/commerce/presentation/pages/orders_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class OrdersModule extends FeatureModule {
  @override
  String get id => 'orders';

  @override
  String name(BuildContext context) => AppLocalizations.of(context).orders;

  @override
  IconData? get icon => Icons.receipt_long_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 30;

  @override
  Set<ModuleCapability> get capabilities => {};

  @override
  List<String> get dependsOn => ['commerce'];

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/orders',
          name: 'orders',
          builder: (context, state) => const OrdersPage(),
        ),
      ],
    );
  }
}
