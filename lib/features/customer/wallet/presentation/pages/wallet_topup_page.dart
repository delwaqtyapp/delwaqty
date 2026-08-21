import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/wallet/wallet_module.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class WalletTopUpPage extends ConsumerStatefulWidget {
  const WalletTopUpPage({super.key});

  @override
  ConsumerState<WalletTopUpPage> createState() => _WalletTopUpPageState();
}

class _WalletTopUpPageState extends ConsumerState<WalletTopUpPage> {
  final _amountController = TextEditingController();
  String _selectedMethod = 'apple_pay';
  bool _loading = false;

  final _presetAmounts = [50.0, 100.0, 200.0, 500.0];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleTopUp() async {
    final l10n = AppLocalizations.of(context);
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      AppSnackbar.info(context, message: l10n.enterValidAmount);
      return;
    }

    setState(() => _loading = true);
    try {
      final authState = ref.read(authStateProvider);
      if (authState is! AuthAuthenticated) return;

      final repo = ref.read(walletRepositoryProvider);
      await repo.topUp(authState.user.id, amount, _selectedMethod);

      ref.invalidate(walletBalanceProvider(authState.user.id));
      ref.invalidate(walletTransactionsProvider(authState.user.id));

      if (mounted) {
        AppSnackbar.success(context, message: l10n.topUpSuccessful);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, message: l10n.somethingWentWrong);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.topUp)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.selectAmount,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetAmounts.map((amount) {
              final isSelected = _amountController.text == amount.toStringAsFixed(0);
              return ChoiceChip(
                label: Text(l10n.amountWithCurrency(amount.toStringAsFixed(0), l10n.currencySymbol)),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _amountController.text = amount.toStringAsFixed(0));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.selectAmount,
              prefixText: '${l10n.currencySymbol} ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.paymentMethod,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _PaymentMethodTile(
            icon: Icons.phone_iphone_rounded,
            title: l10n.applePay,
            isSelected: _selectedMethod == 'apple_pay',
            onTap: () => setState(() => _selectedMethod = 'apple_pay'),
          ),
          const SizedBox(height: 8),
          _PaymentMethodTile(
            icon: Icons.credit_card_rounded,
            title: l10n.creditCard,
            isSelected: _selectedMethod == 'credit_card',
            onTap: () => setState(() => _selectedMethod = 'credit_card'),
          ),
          const SizedBox(height: 8),
          _PaymentMethodTile(
            icon: Icons.account_balance_rounded,
            title: l10n.bankTransfer,
            isSelected: _selectedMethod == 'bank_transfer',
            onTap: () => setState(() => _selectedMethod = 'bank_transfer'),
          ),
          const SizedBox(height: 32),
          AppButton(
            onPressed: _handleTopUp,
            isLoading: _loading,
            isExpanded: true,
            child: Text(l10n.confirmTopUp),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
