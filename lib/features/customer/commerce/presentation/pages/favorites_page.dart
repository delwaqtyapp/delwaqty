import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/merchant_card.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/product_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';

final _favoritesProvider = FutureProvider<List<Favorite>>((ref) async {
  final repo = ref.watch(favoriteRepositoryProvider);
  return repo.getFavorites();
});

final _favoriteMerchantsProvider = FutureProvider<List<Merchant>>((ref) async {
  final favs = await ref.watch(_favoritesProvider.future);
  final merchantFavs = favs.where((f) => f.type == FavoriteType.merchant);
  final repo = ref.watch(merchantRepositoryProvider);
  final merchants = <Merchant>[];
  for (final fav in merchantFavs) {
    final m = await repo.getMerchantById(fav.targetId);
    if (m != null) merchants.add(m);
  }
  return merchants;
});

final _favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final favs = await ref.watch(_favoritesProvider.future);
  final productFavs = favs.where((f) => f.type == FavoriteType.product);
  final repo = ref.watch(productRepositoryProvider);
  final products = <Product>[];
  for (final fav in productFavs) {
    final p = await repo.getProductById(fav.targetId);
    if (p != null) products.add(p);
  }
  return products;
});

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myFavorites),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.favoriteMerchants),
            Tab(text: l10n.favoriteProducts),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_favoritesProvider);
          ref.invalidate(_favoriteMerchantsProvider);
          ref.invalidate(_favoriteProductsProvider);
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _MerchantFavoritesTab(l10n: l10n),
            _ProductFavoritesTab(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _MerchantFavoritesTab extends ConsumerWidget {
  const _MerchantFavoritesTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(_favoriteMerchantsProvider);

    return merchantsAsync.when(
      data: (merchants) {
        if (merchants.isEmpty) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.noFavorites,
                  message: l10n.noFavoritesMessage,
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: merchants.length,
          itemBuilder: (context, index) {
            final merchant = merchants[index];
            return AnimatedFadeIn(
              delay: Duration(milliseconds: 80 * index),
              child: MerchantCard(
                merchant: merchant,
                onTap: () =>
                    context.push('/market/merchant/${merchant.id}'),
              ),
            );
          },
        );
      },
      loading: () => ListView(
        children: const [
          SizedBox(height: 16),
          SkeletonCard(),
          SkeletonCard(),
          SkeletonCard(),
        ],
      ),
      error: (e, _) => ErrorState(
        title: l10n.error,
        message: e.toString(),
        onRetry: () => ref.invalidate(_favoriteMerchantsProvider),
        retryLabel: l10n.retry,
      ),
    );
  }
}

class _ProductFavoritesTab extends ConsumerWidget {
  const _ProductFavoritesTab({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_favoriteProductsProvider);

    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: l10n.noFavorites,
                  message: l10n.noFavoritesMessage,
                ),
              ),
            ],
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return AnimatedFadeIn(
              delay: Duration(milliseconds: 80 * index),
              child: ProductCard(
                product: product,
                onTap: () => context.push(
                  '/market/merchant/${product.merchantId}/product/${product.id}',
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: AppLoaderCircular()),
      error: (e, _) => ErrorState(
        title: l10n.error,
        message: e.toString(),
        onRetry: () => ref.invalidate(_favoriteProductsProvider),
        retryLabel: l10n.retry,
      ),
    );
  }
}
