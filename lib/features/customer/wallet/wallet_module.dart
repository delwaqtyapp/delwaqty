import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/features/customer/wallet/domain/repositories/wallet_repository.dart';
import 'package:delwaqty/features/customer/wallet/data/datasources/remote/supabase_wallet_data_source.dart';
import 'package:delwaqty/features/customer/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_balance.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_transaction.dart';
import 'package:delwaqty/features/customer/wallet/presentation/pages/wallet_page.dart';
import 'package:delwaqty/features/customer/wallet/presentation/pages/wallet_topup_page.dart';
import 'package:delwaqty/features/customer/wallet/presentation/pages/wallet_transactions_page.dart';

final supabaseWalletRepositoryImplProvider = Provider<WalletRepositoryImpl>((ref) {
  return WalletRepositoryImpl(ref.watch(supabaseWalletDataSourceProvider));
});

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => ref.watch(supabaseWalletRepositoryImplProvider),
);

final walletBalanceProvider = FutureProvider.family<WalletBalance, String>((ref, userId) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getBalance(userId);
});

final walletTransactionsProvider = FutureProvider.family<List<WalletTransaction>, String>((ref, userId) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getTransactions(userId);
});

class WalletModule extends FeatureModule {
  @override
  String get id => 'wallet';

  @override
  String name(BuildContext context) => 'Wallet';

  @override
  IconData? get icon => Icons.account_balance_wallet_outlined;

  @override
  bool get isNavModule => false;

  @override
  int get navPriority => 0;

  @override
  Set<ModuleCapability> get capabilities => {ModuleCapability.hasPayments, ModuleCapability.requiresWallet};

  @override
  List<RouteBase> get standaloneRoutes => [
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const WalletPage(),
      routes: [
        GoRoute(
          path: 'topup',
          builder: (context, state) => const WalletTopUpPage(),
        ),
        GoRoute(
          path: 'transactions',
          builder: (context, state) => const WalletTransactionsPage(),
        ),
      ],
    ),
  ];
}
