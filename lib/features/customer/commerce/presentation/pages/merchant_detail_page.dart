import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/catalog_category.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/review.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/product_repository.dart';
import 'package:delwaqty/features/customer/commerce/domain/repositories/catalog_category_repository.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/product_card.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/rating_stars.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/delivery_info.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/product_detail_bottom_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class MerchantDetailPage extends ConsumerStatefulWidget {
  const MerchantDetailPage({required this.merchantId, super.key});

  final String merchantId;

  @override
  ConsumerState<MerchantDetailPage> createState() =>
      _MerchantDetailPageState();
}

class _MerchantDetailPageState extends ConsumerState<MerchantDetailPage> {
  Key _refreshKey = UniqueKey();
  String? _selectedCategoryId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final merchantRepo = ref.watch(merchantRepositoryProvider);
    final productRepo = ref.watch(productRepositoryProvider);
    final categoryRepo = ref.watch(catalogCategoryRepositoryProvider);

    return FutureBuilder<Merchant?>(
      key: _refreshKey,
      future: merchantRepo.getMerchantById(widget.merchantId),
      builder: (context, merchantSnap) {
        if (merchantSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: const Center(child: AppLoaderCircular()),
          );
        }

        final merchant = merchantSnap.data;
        if (merchant == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.error)),
            body: ErrorState(message: l10n.noData),
          );
        }

        return Scaffold(
          bottomNavigationBar: _StickyCartBar(merchantId: widget.merchantId),
          body: RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(merchant, l10n),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMerchantInfo(merchant, l10n),
                      _buildActionButtons(merchant, l10n),
                      _buildBusinessInfoDropdown(merchant, l10n),
                      if (merchant.type == MerchantType.restaurant)
                        _buildFullMenuButton(merchant, l10n),
                      _buildSearchField(merchant, l10n),
                      _buildOffersAndPopular(productRepo, merchant, l10n),
                      _buildCategoriesSection(categoryRepo, l10n),
                      _buildMenuHeader(l10n),
                    ],
                  ),
                ),
                _buildProductGrid(productRepo, merchant, l10n),
                SliverToBoxAdapter(
                  child: _buildReviewsSection(merchant, l10n),
                ),
                SliverToBoxAdapter(
                  child: _buildSimilarMerchants(merchant, l10n),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(Merchant merchant, AppLocalizations l10n) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        CartBadge(onTap: () => context.push('/market/cart')),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'merchant-${merchant.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (merchant.imageUrl != null && merchant.imageUrl!.isNotEmpty)
                Image.network(
                  merchant.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildHeroFallback(merchant),
                )
              else
                _buildHeroFallback(merchant),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _typeColor(merchant.type),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _typeIcon(merchant.type),
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _typeLabel(merchant.type, l10n),
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (merchant.isVerified) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPurple,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 12, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  l10n.verified,
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        _buildOpenBadge(merchant, l10n),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroFallback(Merchant merchant) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _typeColor(merchant.type).withValues(alpha: 0.4),
            context.colorScheme.primaryContainer.withValues(alpha: 0.3),
            context.colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _typeIcon(merchant.type),
          size: 64,
          color: _typeColor(merchant.type).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildOpenBadge(Merchant merchant, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: merchant.isOpenNow
            ? AppColors.successLight.withValues(alpha: 0.9)
            : context.colorScheme.error.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            merchant.isOpenNow ? l10n.open : l10n.closed,
            style: context.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantInfo(Merchant merchant, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedFadeIn(
            child: Text(
              merchant.name,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (merchant.description != null && merchant.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: Text(
                merchant.description!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 150),
            child: RatingStars(
              rating: merchant.rating,
              showCount: true,
              count: merchant.ratingCount,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedFadeIn(
            delay: const Duration(milliseconds: 200),
            child: DeliveryInfo(
              estimatedMinutes: merchant.estimatedDeliveryMinutes,
              deliveryFee: merchant.deliveryFee,
              minimumOrder: merchant.minimumOrder,
            ),
          ),
          if (merchant.address != null) ...[
            const SizedBox(height: 8),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 250),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      merchant.address!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Merchant merchant, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 300),
        child: Row(
          children: [
            _ActionButton(
              icon: Icons.share_outlined,
              label: l10n.shareMerchant,
              onTap: () {
                Clipboard.setData(ClipboardData(text: merchant.name));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(merchant.name),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.directions_outlined,
              label: l10n.directions,
              onTap: () async {
                final uri = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${merchant.latitude},${merchant.longitude}',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.somethingWentWrong)),
                  );
                }
              },
            ),
            const Spacer(),
            FavoriteButton(
              targetId: merchant.id,
              type: FavoriteType.merchant,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullMenuButton(Merchant merchant, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 350),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/restaurant/${merchant.id}'),
            icon: const Icon(Icons.restaurant_outlined, size: 20),
            label: Text(l10n.viewFullMenu),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(Merchant merchant, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 350),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: l10n.searchInMerchant(merchant.name),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersAndPopular(
    ProductRepository productRepo,
    Merchant merchant,
    AppLocalizations l10n,
  ) {
    return FutureBuilder<List<Product>>(
      future: productRepo.getProducts(merchantId: widget.merchantId),
      builder: (context, snap) {
        final products = snap.data ?? [];
        if (products.isEmpty) return const SizedBox.shrink();

        final offers = products.where((p) =>
            p.originalPrice != null && p.originalPrice! > p.price).toList();
        final popular = products.where((p) => p.isFeatured).toList();

        if (offers.isEmpty && popular.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (offers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_outlined, size: 20, color: context.colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      l10n.offers,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: offers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _OfferCard(product: offers[index], merchantId: widget.merchantId, merchant: merchant),
                ),
              ),
            ],
            if (popular.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.star_outline_rounded, size: 20, color: AppColors.rating),
                    const SizedBox(width: 8),
                    Text(
                      l10n.popularItems,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: popular.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _OfferCard(product: popular[index], merchantId: widget.merchantId, merchant: merchant),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCategoriesSection(
    CatalogCategoryRepository categoryRepo,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 400),
        child: FutureBuilder<List<CatalogCategory>>(
          future: categoryRepo.getCategories(widget.merchantId),
          builder: (context, catSnap) {
            final categories = catSnap.data ?? [];
            if (categories.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategoryId == null;
                    return _CategoryChip(
                      label: l10n.allCategories,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    );
                  }
                  final cat = categories[index - 1];
                  final isSelected = _selectedCategoryId == cat.id;
                  return _CategoryChip(
                    label: cat.name,
                    isSelected: isSelected,
                    onTap: () => setState(() {
                      _selectedCategoryId =
                          isSelected ? null : cat.id;
                    }),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 450),
        child: Text(
          l10n.menu,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(
    ProductRepository productRepo,
    Merchant merchant,
    AppLocalizations l10n,
  ) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<Product>>(
        key: _refreshKey,
        future: productRepo.getProducts(
          merchantId: widget.merchantId,
          categoryId: _selectedCategoryId,
        ),
        builder: (context, prodSnap) {
          if (prodSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: AppLoaderCircular(),
              ),
            );
          }

          final allProducts = prodSnap.data ?? [];
          final products = allProducts.where((p) {
            final matchesSearch = _searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                p.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
            return matchesSearch;
          }).toList();

          if (allProducts.isNotEmpty && products.isEmpty && _searchQuery.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PremiumEmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.noResultsInMerchant,
                message: '',
              ),
            );
          }
          if (products.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PremiumEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: l10n.menu,
                message: l10n.noData,
              ),
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Hero(
                tag: 'product-${product.id}',
                child: GestureDetector(
                  onLongPress: () => _showProductDetail(product, merchant),
                  child: ProductCard(
                    product: product,
                    onTap: () => context.push(
                      '/market/merchant/${widget.merchantId}/product/${product.id}',
                      extra: merchant.name,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewsSection(Merchant merchant, AppLocalizations l10n) {
    return FutureBuilder<List<Review>>(
      future: ref.read(reviewRepositoryProvider).getMerchantReviews(merchant.id, limit: 10),
      builder: (context, snap) {
        final reviews = snap.data ?? [];
        if (reviews.isEmpty) return const SizedBox.shrink();

        final total = reviews.length;
        final avg = reviews.fold<double>(0, (sum, r) => sum + r.rating) / total;
        final counts = List.filled(5, 0);
        for (final r in reviews) {
          final idx = r.rating.round().clamp(1, 5) - 1;
          counts[idx]++;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.reviews_outlined, size: 20, color: context.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.reviews,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    avg.toStringAsFixed(1),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.rating,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded, size: 18, color: AppColors.rating),
                  Text(
                    ' ($total)',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRatingBars(counts, total),
              const SizedBox(height: 16),
              ...reviews.take(3).map((review) => _buildReviewCard(review, l10n)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingBars(List<int> counts, int total) {
    return Column(
      children: List.generate(5, (i) {
        final star = 5 - i;
        final count = counts[i];
        final fraction = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$star',
                  style: context.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 12, color: AppColors.rating),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation(AppColors.rating),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  '$count',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(Review review, AppLocalizations l10n) {
    final initial = (review.userName?.isNotEmpty ?? false)
        ? review.userName![0].toUpperCase()
        : 'U';
    final date = review.createdAt;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.colorScheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? l10n.user,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ...List.generate(5, (i) => Icon(
                  i < review.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 14,
                  color: AppColors.rating,
                )),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                review.comment!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfoDropdown(Merchant merchant, AppLocalizations l10n) {
    final hasInfo = merchant.address != null;
    if (!hasInfo) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AnimatedFadeIn(
        delay: const Duration(milliseconds: 400),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.store_outlined,
                size: 18,
                color: context.colorScheme.primary,
              ),
            ),
            title: Text(
              l10n.businessInfo,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: merchant.address != null
                ? Text(
                    merchant.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: Icon(
              Icons.expand_more_rounded,
              color: context.colorScheme.onSurfaceVariant,
            ),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    if (merchant.address != null)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: l10n.address,
                        value: merchant.address!,
                      ),
                    if (merchant.address != null) const _Divider(),
                    _InfoRow(
                      icon: Icons.access_time_outlined,
                      label: l10n.workingHours,
                      value: merchant.isOpenNow ? l10n.open : l10n.closed,
                      valueColor: merchant.isOpenNow
                          ? AppColors.successLight
                          : context.colorScheme.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimilarMerchants(Merchant merchant, AppLocalizations l10n) {
    return FutureBuilder<List<Merchant>>(
      future: ref.read(merchantRepositoryProvider).getMerchants(type: merchant.type, limit: 10),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final similar = all.where((m) => m.id != merchant.id).toList();
        if (similar.length < 2) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.store_outlined, size: 20, color: context.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.similarMerchants,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: similar.length.clamp(0, 5),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final m = similar[index];
                  return _SimilarMerchantCard(merchant: m);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProductDetail(Product product, Merchant merchant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailBottomSheet(
        product: product,
        merchantId: widget.merchantId,
        merchantName: merchant.name,
        merchantType: merchant.type,
      ),
    );
  }

  IconData _typeIcon(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return Icons.restaurant;
      case MerchantType.grocery:
        return Icons.local_grocery_store;
      case MerchantType.supermarket:
        return Icons.shopping_cart;
      case MerchantType.fruits:
        return Icons.eco;
      case MerchantType.meat:
        return Icons.set_meal;
      case MerchantType.seafood:
        return Icons.phishing;
      case MerchantType.pharmacy:
        return Icons.local_pharmacy;
      case MerchantType.bakery:
        return Icons.bakery_dining;
      case MerchantType.sweets:
        return Icons.cake;
      case MerchantType.flowers:
        return Icons.local_florist;
      case MerchantType.clothing:
        return Icons.dry_cleaning;
      case MerchantType.shoes:
        return Icons.pedal_bike;
      case MerchantType.electronics:
        return Icons.devices;
      case MerchantType.mobile:
        return Icons.phone_iphone;
      case MerchantType.furniture:
        return Icons.chair;
      case MerchantType.appliances:
        return Icons.kitchen;
      case MerchantType.fashion:
        return Icons.checkroom;
      case MerchantType.cafe:
        return Icons.coffee;
      case MerchantType.petShop:
        return Icons.pets;
      case MerchantType.fitness:
        return Icons.fitness_center;
      case MerchantType.gas:
        return Icons.local_gas_station;
      case MerchantType.carwash:
        return Icons.local_car_wash;
      case MerchantType.home:
        return Icons.home_repair_service;
      case MerchantType.other:
        return Icons.store;
    }
  }

  Color _typeColor(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return AppColors.merchantFood;
      case MerchantType.grocery:
        return AppColors.merchantGrocery;
      case MerchantType.supermarket:
        return AppColors.serviceSupermarket;
      case MerchantType.fruits:
        return AppColors.serviceFruits;
      case MerchantType.meat:
        return AppColors.serviceMeat;
      case MerchantType.seafood:
        return AppColors.serviceSeafood;
      case MerchantType.pharmacy:
        return AppColors.merchantPharmacy;
      case MerchantType.electronics:
        return AppColors.merchantElectronics;
      case MerchantType.fashion:
        return AppColors.merchantFashion;
      case MerchantType.furniture:
        return AppColors.merchantFurniture;
      case MerchantType.flowers:
        return AppColors.brandViolet;
      case MerchantType.bakery:
        return AppColors.warningLight;
      case MerchantType.sweets:
        return AppColors.serviceSweets;
      case MerchantType.clothing:
        return AppColors.serviceClothing;
      case MerchantType.shoes:
        return AppColors.serviceShoes;
      case MerchantType.mobile:
        return AppColors.serviceMobile;
      case MerchantType.appliances:
        return AppColors.serviceAppliances;
      case MerchantType.cafe:
        return AppColors.serviceCafe;
      case MerchantType.petShop:
        return AppColors.servicePetShop;
      case MerchantType.fitness:
        return AppColors.serviceFitness;
      case MerchantType.gas:
        return AppColors.serviceGas;
      case MerchantType.carwash:
        return AppColors.serviceCarwash;
      case MerchantType.home:
        return AppColors.serviceHome;
      case MerchantType.other:
        return AppColors.brandPurple;
    }
  }

  String _typeLabel(MerchantType type, AppLocalizations l10n) {
    switch (type) {
      case MerchantType.restaurant:
        return l10n.typeRestaurant;
      case MerchantType.grocery:
        return l10n.typeGrocery;
      case MerchantType.supermarket:
        return l10n.typeSupermarket;
      case MerchantType.fruits:
        return l10n.typeFruits;
      case MerchantType.meat:
        return l10n.typeMeat;
      case MerchantType.seafood:
        return l10n.typeSeafood;
      case MerchantType.pharmacy:
        return l10n.typePharmacy;
      case MerchantType.flowers:
        return l10n.typeFlowers;
      case MerchantType.bakery:
        return l10n.typeBakery;
      case MerchantType.sweets:
        return l10n.typeSweets;
      case MerchantType.clothing:
        return l10n.typeClothing;
      case MerchantType.shoes:
        return l10n.typeShoes;
      case MerchantType.electronics:
        return l10n.typeElectronics;
      case MerchantType.mobile:
        return l10n.typeMobile;
      case MerchantType.furniture:
        return l10n.typeFurniture;
      case MerchantType.appliances:
        return l10n.typeAppliances;
      case MerchantType.fashion:
        return l10n.typeFashion;
      case MerchantType.cafe:
        return l10n.typeCafe;
      case MerchantType.petShop:
        return l10n.typePetShop;
      case MerchantType.fitness:
        return l10n.typeFitness;
      case MerchantType.gas:
        return l10n.typeGas;
      case MerchantType.carwash:
        return l10n.typeCarwash;
      case MerchantType.home:
        return l10n.typeHome;
      case MerchantType.other:
        return l10n.typeOther;
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 20, color: context.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.product,
    required this.merchantId,
    required this.merchant,
  });

  final Product product;
  final String merchantId;
  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final discount = product.originalPrice != null && product.originalPrice! > product.price
        ? ((1 - product.price / product.originalPrice!) * 100).round()
        : 0;

    return GestureDetector(
      onTap: () => context.push(
        '/market/merchant/$merchantId/product/${product.id}',
        extra: merchant.name,
      ),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 72,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        context.colorScheme.surface,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: Image.network(product.imageUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.shopping_bag_outlined,
                              size: 28,
                              color: context.colorScheme.primary.withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 28,
                            color: context.colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colorScheme.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-$discount%',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}',
                        style: context.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colorScheme.primary,
                        ),
                      ),
                      if (discount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          product.originalPrice!.toStringAsFixed(0),
                          style: context.textTheme.labelSmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        height: 1,
        color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
      ),
    );
  }
}

class _SimilarMerchantCard extends StatelessWidget {
  const _SimilarMerchantCard({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/market/merchant/${merchant.id}'),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    context.colorScheme.surface,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: merchant.imageUrl != null && merchant.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: Image.network(merchant.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          _typeIcon(merchant.type),
                          size: 28,
                          color: context.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        _typeIcon(merchant.type),
                        size: 28,
                        color: context.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: AppColors.rating),
                      const SizedBox(width: 2),
                      Text(
                        merchant.rating.toStringAsFixed(1),
                        style: context.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        merchant.isOpenNow ? Icons.circle : Icons.circle_outlined,
                        size: 8,
                        color: merchant.isOpenNow ? AppColors.successLight : context.colorScheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(MerchantType type) {
    switch (type) {
      case MerchantType.restaurant:
        return Icons.restaurant;
      case MerchantType.grocery:
        return Icons.local_grocery_store;
      case MerchantType.supermarket:
        return Icons.shopping_cart;
      case MerchantType.fruits:
        return Icons.eco;
      case MerchantType.meat:
        return Icons.set_meal;
      case MerchantType.seafood:
        return Icons.phishing;
      case MerchantType.pharmacy:
        return Icons.local_pharmacy;
      case MerchantType.bakery:
        return Icons.bakery_dining;
      case MerchantType.sweets:
        return Icons.cake;
      case MerchantType.flowers:
        return Icons.local_florist;
      case MerchantType.clothing:
        return Icons.dry_cleaning;
      case MerchantType.shoes:
        return Icons.pedal_bike;
      case MerchantType.electronics:
        return Icons.devices;
      case MerchantType.mobile:
        return Icons.phone_iphone;
      case MerchantType.furniture:
        return Icons.chair;
      case MerchantType.appliances:
        return Icons.kitchen;
      case MerchantType.fashion:
        return Icons.checkroom;
      case MerchantType.cafe:
        return Icons.coffee;
      case MerchantType.petShop:
        return Icons.pets;
      case MerchantType.fitness:
        return Icons.fitness_center;
      case MerchantType.gas:
        return Icons.local_gas_station;
      case MerchantType.carwash:
        return Icons.local_car_wash;
      case MerchantType.home:
        return Icons.home_repair_service;
      case MerchantType.other:
        return Icons.store;
    }
  }
}

class _StickyCartBar extends ConsumerWidget {
  const _StickyCartBar({required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final cart = cartAsync.value;

    if (cart == null || cart.items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandGradientStart, AppColors.brandGradientEnd],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '${cart.items.length}',
                style: context.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cart.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${cart.total.toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.push('/market/cart'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).viewCart,
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.brandGradientStart, AppColors.brandGradientEnd],
                )
              : null,
          color: isSelected ? null : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: isSelected ? Colors.white : context.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
