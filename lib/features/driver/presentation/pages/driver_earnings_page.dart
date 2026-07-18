import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

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
            Center(child: Text(l10n.errorWithMessage(e.toString()))),
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(driverStatsProvider(driverId));
        ref.invalidate(driverEarningsProvider(driverId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
            data: (stats) => _BalanceCard(driverId: driverId, stats: stats),
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
                          ? Colors.green.withValues(alpha: 0.15)
                          : Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.15),
                      child: Icon(
                        positive
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: positive
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    title: Text(_typeLabel(l10n, e.type)),
                    subtitle: Text(
                      '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: Text(
                      '${positive ? '+' : ''}${l10n.amountWithCurrency(e.amount.toStringAsFixed(0), l10n.currencySymbol)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: positive
                            ? Colors.green
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
      case 'withdrawal':
        return l10n.withdrawalType;
      default:
        return l10n.adjustment;
    }
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
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 4),
          Text(
            l10n.amountWithCurrency(
                stats.balance.toStringAsFixed(2), l10n.currencySymbol),
            style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold),
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
                color: Colors.white.withValues(alpha: 0.85))),
        Text(
          l10n.amountWithCurrency(value.toStringAsFixed(0), l10n.currencySymbol),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
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
          .showSnackBar(SnackBar(content: Text(l10n.errorWithMessage(e.toString()))));
    }
  }
}
