import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/merchant_type_chip.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';

final _merchantsFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants();
});

final _featuredFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getFeaturedMerchants();
});

final _selectedTypeProvider = StateProvider<MerchantType?>((_) => null);

class CommerceDiscoveryPage extends ConsumerWidget {
  const CommerceDiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedType = ref.watch(_selectedTypeProvider);
    final merchantsAsync = ref.watch(_merchantsFutureProvider);
    final featuredAsync = ref.watch(_featuredFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [CartBadge(onTap: () => context.push('/market/cart'))],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_merchantsFutureProvider);
          ref.invalidate(_featuredFutureProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search merchants, products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              onTap: () => context.push('/market/search'),
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Category chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: selectedType == null,
                      onSelected: (_) =>
                          ref.read(_selectedTypeProvider.notifier).state = null,
                    ),
                  ),
                  ...MerchantType.values.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MerchantTypeChip(
                        type: type,
                        onTap: () =>
                            ref.read(_selectedTypeProvider.notifier).state =
                                type,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Featured merchants
            featuredAsync.when(
              data: (merchants) {
                if (merchants.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Featured',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: merchants.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final merchant = merchants[index];
                          return SizedBox(
                            width: 260,
                            child: MerchantCard(
                              merchant: merchant,
                              onTap: () => context.push(
                                '/market/merchant/${merchant.id}',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const SizedBox(),
            ),

            // All merchants
            Text(
              'All Merchants',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            merchantsAsync.when(
              data: (merchants) {
                final filtered = selectedType != null
                    ? merchants.where((m) => m.type == selectedType).toList()
                    : merchants;

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No merchants found'),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final merchant = filtered[index];
                    return MerchantCard(
                      merchant: merchant,
                      onTap: () =>
                          context.push('/market/merchant/${merchant.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
