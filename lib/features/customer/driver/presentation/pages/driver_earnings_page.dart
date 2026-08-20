import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/driver/driver_module.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _walletDetailProvider =
    FutureProvider.family<WalletDetail, String>((ref, driverId) async {
  final repo = ref.watch(driverRepositoryProvider);
  return repo.getWalletDetail(driverId);
});

class DriverEarningsPage extends ConsumerWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.wallet)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }
    final profileAsync = ref.watch(driverProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wallet)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.somethingWentWrong)),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.noActiveTrip));
          }
          return _EarningsBody(driverId: profile.id);
        },
      ),
    );
  }
}

class _EarningsBody extends ConsumerWidget {
  const _EarningsBody({required this.driverId});
  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(driverStatsProvider(driverId));
    final earningsAsync = ref.watch(driverEarningsProvider(driverId));
    final walletAsync = ref.watch(_walletDetailProvider(driverId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverStatsProvider(driverId));
        ref.invalidate(driverEarningsProvider(driverId));
        ref.invalidate(_walletDetailProvider(driverId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => _BalanceCard(driverId: driverId, stats: stats),
          ),
          const SizedBox(height: 16),
          walletAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (wallet) => _WalletBreakdownCard(wallet: wallet),
          ),
          const SizedBox(height: 24),
          Text(l10n.earningsHistory,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          earningsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
            data: (earnings) {
              if (earnings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.noActiveTrip)),
                );
              }
              return Column(
                children: earnings.map((e) {
                  final positive = e.amount >= 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: positive
                          ? AppColors.successLight.withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.15),
                      child: Icon(
                        positive
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: positive
                            ? AppColors.successLight
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    title: Text(_typeLabel(l10n, e.type)),
                    subtitle: Text(
                      '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: Text(
                      '${positive ? '+' : ''}${l10n.amountWithCurrency(e.amount.toStringAsFixed(0), l10n.currencySymbol)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: positive
                            ? AppColors.successLight
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'trip':
        return l10n.trip;
      case 'bonus':
        return l10n.bonus;
      case 'tip':
        return l10n.tip;
      case 'incentive':
        return l10n.incentiveBalance;
      case 'withdrawal':
        return l10n.withdrawalType;
      default:
        return l10n.adjustment;
    }
  }
}

class _WalletBreakdownCard extends StatelessWidget {
  const _WalletBreakdownCard({required this.wallet});
  final WalletDetail wallet;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.walletBreakdown,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _BreakdownRow(
            label: l10n.bonusBalance,
            value: wallet.bonusBalance,
            color: AppColors.warningLight,
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: l10n.incentiveBalance,
            value: wallet.incentiveBalance,
            color: Colors.purple,
          ),
          const Divider(height: 24),
          _BreakdownRow(
            label: l10n.pendingWithdrawals,
            value: wallet.pendingWithdrawals,
            color: AppColors.rating,
          ),
          const SizedBox(height: 8),
          _BreakdownRow(
            label: l10n.totalWithdrawn,
            value: wallet.totalWithdrawn,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.amountWithCurrency(value.toStringAsFixed(0), l10n.currencySymbol),
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.driverId, required this.stats});
  final String driverId;
  final DriverStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          theme.colorScheme.primary,
          theme.colorScheme.primary.withValues(alpha: 0.8),
        ]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.wallet,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Text(
            l10n.amountWithCurrency(
                stats.balance.toStringAsFixed(2), l10n.currencySymbol),
            style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _sub(context, l10n.weeklyEarnings,
                    stats.weekEarnings, l10n),
              ),
              Expanded(
                child: _sub(context, l10n.pendingWithdrawals,
                    stats.pendingWithdrawals, l10n),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: stats.balance <= 0
                  ? null
                  : () => _withdrawDialog(context, ref, stats),
              child: Text(l10n.withdrawFunds),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sub(BuildContext context, String label, double value,
      AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85))),
        Text(
          l10n.amountWithCurrency(value.toStringAsFixed(0), l10n.currencySymbol),
          style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _withdrawDialog(
      BuildContext context, WidgetRef ref, DriverStats stats) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
        text: stats.balance.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.requestWithdrawal),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.enterAmount,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(v);
            },
            child: Text(l10n.requestWithdrawal),
          ),
        ],
      ),
    );
    if (amount == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (amount <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.minimumFareNotMet)));
      return;
    }
    if (amount > stats.balance) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.amountExceedsBalance)));
      return;
    }
    try {
      await ref
          .read(dispatchRepositoryProvider)
          .requestWithdrawal(driverId, amount);
      ref.invalidate(driverStatsProvider(driverId));
      ref.invalidate(driverEarningsProvider(driverId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.withdrawalRequested)));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    }
  }
}
