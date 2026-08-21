import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/wallet/wallet_module.dart';
import 'package:delwaqty/features/customer/wallet/domain/entities/wallet_transaction.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.wallet)),
        body: Center(
          child: PremiumEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: l10n.login,
            message: l10n.loginToViewWallet,
          ),
        ),
      );
    }

    final balanceAsync = ref.watch(walletBalanceProvider(userId));
    final transactionsAsync = ref.watch(walletTransactionsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wallet)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider(userId));
          ref.invalidate(walletTransactionsProvider(userId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedFadeIn(
              child: balanceAsync.when(
                data: (balance) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.availableBalance,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${balance.balance.toStringAsFixed(2)} ${balance.currency}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const ShimmerCard(height: 140),
                error: (e, _) => PremiumEmptyState(
                  icon: Icons.error_outline,
                  title: l10n.error,
                  message: l10n.errorLoading,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.add_rounded,
                      label: l10n.topUp,
                      onTap: () => context.push('/wallet/topup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: l10n.transactions,
                      onTap: () => context.push('/wallet/transactions'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: Text(
                l10n.recentTransactions,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 300),
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: PremiumEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: l10n.noTransactions,
                        message: l10n.topUpToGetStarted,
                      ),
                    );
                  }
                  return Column(
                    children: transactions.take(5).map((tx) {
                      return _TransactionTile(transaction: tx);
                    }).toList(),
                  );
                },
                loading: () => Column(
                  children: List.filled(3, const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerCard(height: 60),
                  )),
                ),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isCredit = transaction.type == TransactionType.topup ||
        transaction.type == TransactionType.refund;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit
                    ? AppColors.successLight.withValues(alpha: 0.1)
                    : theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIcon(transaction.type),
                color: isCredit ? AppColors.successLight : theme.colorScheme.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                '${isCredit ? '+' : '-'}${l10n.amountWithCurrency(transaction.amount.toStringAsFixed(2), l10n.currencySymbol)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isCredit ? AppColors.successLight : theme.colorScheme.error,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(TransactionType type) {
    switch (type) {
      case TransactionType.topup:
        return Icons.add_circle_outline;
      case TransactionType.payment:
        return Icons.payment_rounded;
      case TransactionType.refund:
        return Icons.replay_rounded;
      case TransactionType.withdrawal:
        return Icons.money_off_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
