import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';

class AdminReceivingWalletsPage extends ConsumerStatefulWidget {
  const AdminReceivingWalletsPage({super.key});

  @override
  ConsumerState<AdminReceivingWalletsPage> createState() =>
      _AdminReceivingWalletsPageState();
}

class _AdminReceivingWalletsPageState
    extends ConsumerState<AdminReceivingWalletsPage> {
  Future<void> _addPlatform() async {
    final methodController = TextEditingController(text: 'bank_transfer');
    final nameController = TextEditingController();
    final accountController = TextEditingController();
    final numberController = TextEditingController();
    final walletController = TextEditingController();
    final instrController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Platform Receiving Account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: methodController,
                decoration: const InputDecoration(labelText: 'Method Type'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Account Number'),
              ),
              TextField(
                controller: walletController,
                decoration: const InputDecoration(labelText: 'Wallet Number'),
              ),
              TextField(
                controller: instrController,
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
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
          const SnackBar(content: Text('Receiving account added')),
        );
      }
      ref.invalidate(adminReceivingAccountsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addWallet() async {
    final regionController = TextEditingController();
    final methodController = TextEditingController(text: 'bank_transfer');
    final walletController = TextEditingController();
    final accountController = TextEditingController();
    final providerController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Receiving Wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: regionController,
                decoration: const InputDecoration(labelText: 'Region ID (UUID)'),
              ),
              TextField(
                controller: methodController,
                decoration: const InputDecoration(labelText: 'Method Type'),
              ),
              TextField(
                controller: walletController,
                decoration: const InputDecoration(labelText: 'Wallet Number'),
              ),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              TextField(
                controller: providerController,
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (regionController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Add'),
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
          const SnackBar(content: Text('Receiving wallet added')),
        );
      }
      ref.invalidate(adminReceivingWalletsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(adminIsOwnerProvider);
    final accountsAsync = ref.watch(adminReceivingAccountsProvider);
    final walletsAsync = ref.watch(adminReceivingWalletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receiving Accounts'),
        actions: [
          IconButton(
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
            label: const Text('Wallet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Platform Receiving Accounts',
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
              message: e.toString(),
            ),
            data: (accounts) {
              if (accounts.isEmpty) {
                return const PremiumEmptyState(
                  icon: Icons.account_balance_rounded,
                  title: 'No platform accounts',
                  message: 'Owner can configure global receiving accounts.',
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
            'Regional Admin Receiving Wallets',
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
              message: e.toString(),
            ),
            data: (wallets) {
              if (wallets.isEmpty) {
                return const PremiumEmptyState(
                  icon: Icons.wallet_rounded,
                  title: 'No receiving wallets',
                  message: 'Add a receiving wallet for your region.',
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
                            'Region: ${w['region_id']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (w['wallet_number'] != null)
                            Text(
                              'Wallet: ${w['wallet_number']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (w['account_name'] != null)
                            Text(
                              'Account: ${w['account_name']}',
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
