import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';

class AdminReceivingWalletsPage extends ConsumerStatefulWidget {
  const AdminReceivingWalletsPage({super.key});

  @override
  ConsumerState<AdminReceivingWalletsPage> createState() =>
      _AdminReceivingWalletsPageState();
}

class _AdminReceivingWalletsPageState
    extends ConsumerState<AdminReceivingWalletsPage> {
  Future<void> _addPlatform() async {
    final l10n = AppLocalizations.of(context);
    final methodController = TextEditingController(text: 'bank_transfer');
    final nameController = TextEditingController();
    final accountController = TextEditingController();
    final numberController = TextEditingController();
    final walletController = TextEditingController();
    final instrController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:  Text(l10n.addPlatformReceivingAccount),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: methodController,
                decoration: InputDecoration(labelText: l10n.methodType),
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.displayNameLabel),
              ),
              TextField(
                controller: accountController,
                decoration: InputDecoration(labelText: l10n.accountNameLabel),
              ),
              TextField(
                controller: numberController,
                decoration: InputDecoration(labelText: l10n.accountNumberLabel),
              ),
              TextField(
                controller: walletController,
                decoration: InputDecoration(labelText: l10n.walletNumberLabel),
              ),
              TextField(
                controller: instrController,
                decoration: InputDecoration(labelText: l10n.instructionsLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:  Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(l10n.addLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminFinancialRepositoryProvider).ownerCreateReceivingAccount(
            methodType: methodController.text.trim(),
            displayName: nameController.text.trim(),
            accountName: accountController.text.trim(),
            accountNumber: numberController.text.trim(),
            walletNumber: walletController.text.trim(),
            instructions: instrController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.receivingAccountAdded)),
        );
      }
      ref.invalidate(adminReceivingAccountsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    }
  }

  Future<void> _togglePlatform(String id, bool active) async {
    try {
      await ref
          .read(adminFinancialRepositoryProvider)
          .ownerUpdateReceivingAccount(id: id, isActive: !active);
      ref.invalidate(adminReceivingAccountsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    }
  }

  Future<void> _addWallet() async {
    final l10n = AppLocalizations.of(context);
    final regionController = TextEditingController();
    final methodController = TextEditingController(text: 'bank_transfer');
    final walletController = TextEditingController();
    final accountController = TextEditingController();
    final providerController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:  Text(l10n.addReceivingWallet),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: regionController,
                decoration: InputDecoration(labelText: l10n.regionIdLabel),
              ),
              TextField(
                controller: methodController,
                decoration: InputDecoration(labelText: l10n.methodType),
              ),
              TextField(
                controller: walletController,
                decoration: InputDecoration(labelText: l10n.walletNumberLabel),
              ),
              TextField(
                controller: accountController,
                decoration: InputDecoration(labelText: l10n.accountNameLabel),
              ),
              TextField(
                controller: providerController,
                decoration: InputDecoration(labelText: l10n.provider),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:  Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (regionController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(l10n.addLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminFinancialRepositoryProvider).createAdminReceivingWallet(
            regionId: regionController.text.trim(),
            methodType: methodController.text.trim(),
            walletNumber: walletController.text.trim(),
            accountName: accountController.text.trim(),
            provider: providerController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.receivingWalletAdded)),
        );
      }
      ref.invalidate(adminReceivingWalletsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(adminIsOwnerProvider).value ?? false;
    final accountsAsync = ref.watch(adminReceivingAccountsProvider);
    final walletsAsync = ref.watch(adminReceivingWalletsProvider);

    return Scaffold(
      appBar: AppBar(
        title:  Text(l10n.receivingAccounts),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(adminReceivingAccountsProvider);
              ref.invalidate(adminReceivingWalletsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner)
            FloatingActionButton.small(
              heroTag: 'platform',
              onPressed: _addPlatform,
              child: const Icon(Icons.business_rounded),
            ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'wallet',
            onPressed: _addWallet,
            icon: const Icon(Icons.add),
            label:  Text(l10n.wallet),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            l10n.platformReceivingAccounts,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          accountsAsync.when(
            loading: () => const Center(child: AppLoaderCircular()),
            error: (e, _) => PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: appErrorText(context, e),
            ),
            data: (accounts) {
              if (accounts.isEmpty) {
                return PremiumEmptyState(
                  icon: Icons.account_balance_rounded,
                  title: l10n.addPlatformReceivingAccount,
                  message: l10n.receivingAccountAdded,
                );
              }
              return Column(
                children: [
                  for (final a in accounts)
                    PremiumCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${a.methodType} • ${a.accountName ?? a.walletNumber ?? '-'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (isOwner)
                            Switch(
                              value: a.isActive,
                              onChanged: (_) =>
                                  _togglePlatform(a.id, a.isActive),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.receivingAccounts,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          walletsAsync.when(
            loading: () => const Center(child: AppLoaderCircular()),
            error: (e, _) => PremiumEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.error,
              message: appErrorText(context, e),
            ),
            data: (wallets) {
              if (wallets.isEmpty) {
                return PremiumEmptyState(
                  icon: Icons.wallet_rounded,
                  title: l10n.addReceivingWallet,
                  message: l10n.receivingWalletAdded,
                );
              }
              return Column(
                children: [
                  for (final w in wallets)
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${w['method_type']} • ${w['provider'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${l10n.regionIdLabel}: ${w['region_id']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (w['wallet_number'] != null)
                            Text(
                              '${l10n.walletNumberLabel}: ${w['wallet_number']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (w['account_name'] != null)
                            Text(
                              '${l10n.accountNameLabel}: ${w['account_name']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
