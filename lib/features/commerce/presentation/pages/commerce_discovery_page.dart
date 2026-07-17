import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/merchant_type_chip.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _merchantsFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchants();
});

final _featuredFutureProvider = FutureProvider<List<Merchant>>((ref) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getFeaturedMerchants();
});

final _selectedTypeProvider = StateProvider<MerchantType?>((_) => null);

class CommerceDiscoveryPage extends ConsumerStatefulWidget {
  const CommerceDiscoveryPage({super.key});

  @override
  ConsumerState<CommerceDiscoveryPage> createState() => _CommerceDiscoveryPageState();
}

class _CommerceDiscoveryPageState extends ConsumerState<CommerceDiscoveryPage> {
  bool _initialFilterSet = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selectedType = ref.watch(_selectedTypeProvider);
    final merchantsAsync = ref.watch(_merchantsFutureProvider);
    final featuredAsync = ref.watch(_featuredFutureProvider);

    final extra = GoRouterState.of(context).uri.queryParameters['type'];
    if (!_initialFilterSet && extra != null) {
      _initialFilterSet = true;
      final match = MerchantType.values.where((t) => t.name == extra).firstOrNull;
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(_selectedTypeProvider.notifier).state = match;
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discover),
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
            AnimatedFadeIn(
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchMerchantsProducts,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                ),
                onTap: () => context.push('/market/search'),
                readOnly: true,
              ),
            ),
            const SizedBox(height: 16),

            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(l10n.all),
                        selected: selectedType == null,
                        onSelected: (_) => ref
                            .read(_selectedTypeProvider.notifier)
                            .state = null,
                      ),
                    ),
                    ...MerchantType.values.map(
                      (type) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: MerchantTypeChip(
                          type: type,
                          onTap: () => ref
                              .read(_selectedTypeProvider.notifier)
                              .state = type,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            featuredAsync.when(
              data: (merchants) {
                if (merchants.isEmpty) return const SizedBox();
                return AnimatedFadeIn(
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.featured,
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
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
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SizedBox(),
            ),

            AnimatedFadeIn(
              delay: const Duration(milliseconds: 300),
              child: Text(
                l10n.allMerchants,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            merchantsAsync.when(
              data: (merchants) {
                final filtered = selectedType != null
                    ? merchants.where((m) => m.type == selectedType).toList()
                    : merchants;

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: PremiumEmptyState(
                      icon: Icons.store_outlined,
                      title: l10n.noMerchantsFound,
                      message: l10n.nearbyEmptyHint,
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
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
              loading: () => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
                children: const [
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                  ShimmerCard(height: 200),
                ],
              ),
              error: (e, _) => PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.error,
                message: l10n.errorLoading,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(_merchantsFutureProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
