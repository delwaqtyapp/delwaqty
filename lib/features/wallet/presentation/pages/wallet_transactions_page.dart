import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/wallet/wallet_module.dart';
import 'package:delwaqty/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

class WalletTransactionsPage extends ConsumerWidget {
  const WalletTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authStateProvider);

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.transactions)),
        body: const SizedBox.shrink(),
      );
    }

    final transactionsAsync = ref.watch(walletTransactionsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactions)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(walletTransactionsProvider(userId)),
        child: transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return Center(
                child: PremiumEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.noTransactions,
                  message: l10n.topUpToGetStarted,
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: index * 50),
                  child: _TransactionTile(transaction: tx),
                );
              },
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 8,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: ShimmerCard(height: 64),
            ),
          ),
          error: (e, _) => PremiumEmptyState(
            icon: Icons.error_outline,
            title: l10n.error,
            message: l10n.errorLoading,
          ),
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
