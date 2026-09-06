import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/provider/financial/presentation/pages/financial_center_page.dart';
import 'package:delwaqty/features/provider/financial/presentation/pages/topup_request_page.dart';

class FinancialModule extends FeatureModule {
  @override
  String get id => 'provider-financial';

  @override
  String name(BuildContext context) => 'Financial Center';

  @override
  IconData? get icon => Icons.account_balance_wallet_outlined;

  @override
  bool get isNavModule => true;

  @override
  int get navPriority => 20;

  @override
  StatefulShellBranch? buildBranch() {
    return StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/provider-financial-center',
          builder: (context, state) => const FinancialCenterPage(),
          routes: [
            GoRoute(
              path: 'topup',
              builder: (context, state) => const TopupRequestPage(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  List<Override> providerOverrides(Ref ref) => [];
}
