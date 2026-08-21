import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/customer/commerce/presentation/widgets/price_tag.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart'
    as restaurant;
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({
    required this.productId,
    required this.merchantId,
    this.merchantName = '',
    super.key,
  });

  final String productId;
  final String merchantId;
  final String merchantName;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1;
  String? _selectedVariantId;
  final _instructionsController = TextEditingController();
  final Set<String> _selectedModifierIds = {};
  List<ProductModifier> _currentModifiers = [];
  bool _modifiersLoaded = false;

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadModifiers() async {
    if (_modifiersLoaded) return;
    try {
      final repo = ref.read(restaurant.modifierRepositoryProvider);
      final mods = await repo.getModifiers(widget.productId);
      if (mounted) {
        setState(() {
          _currentModifiers = mods;
          _modifiersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product modifiers: $e');
      if (mounted) setState(() => _modifiersLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final productRepo = ref.watch(productRepositoryProvider);

    return FutureBuilder<Product?>(
      future: productRepo.getProductById(widget.productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: const SkeletonCard(),
          );
        }

        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.error)),
            body: ErrorState(message: l10n.noData),
          );
        }

        if (!_modifiersLoaded) _loadModifiers();

        final selectedVariant = _selectedVariantId != null
            ? product.variants
                  .where((v) => v.id == _selectedVariantId)
                  .firstOrNull
            : null;
        final unitPrice = selectedVariant?.price ?? product.price;
        final modifierTotal = _selectedModifierIds.fold<double>(
          0,
          (sum, id) {
            final mod = _currentModifiers
                .where((m) => m.id == id)
                .firstOrNull;
            return sum + (mod?.priceAdjustment ?? 0);
          },
        );
        final totalPrice = (unitPrice + modifierTotal) * _quantity;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [CartBadge(onTap: () => context.push('/market/cart'))],
          ),
          body: ListView(
            children: [
              Hero(
                tag: 'product-${product.id}',
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.colorScheme.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        context.colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        product.name,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          product.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 300),
                      child: PriceTag(
                        price: unitPrice,
                        originalPrice: product.originalPrice,
                        size: 'large',
                      ),
                    ),
                    if (product.variants.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          l10n.details,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 450),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: product.variants.map((v) {
                            final isSelected = v.id == _selectedVariantId;
                            return ChoiceChip(
                              label: Text(
                                '${v.name} - ${v.price.toStringAsFixed(0)} ${l10n.currencySymbol}',
                              ),
                              selected: isSelected,
                              selectedColor:
                                  context.colorScheme.primaryContainer,
                              onSelected: v.isAvailable
                                  ? (_) => setState(
                                      () => _selectedVariantId = v.id,
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    if (_currentModifiers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 470),
                        child: Text(
                          l10n.addOns,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_currentModifiers.length, (i) {
                        final mod = _currentModifiers[i];
                        final isSelected = _selectedModifierIds.contains(mod.id);
                        return AnimatedFadeIn(
                          delay: Duration(milliseconds: 500 + i * 40),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: mod.isAvailable
                                ? (val) => setState(() {
                                    if (val == true) {
                                      _selectedModifierIds.add(mod.id);
                                    } else {
                                      _selectedModifierIds.remove(mod.id);
                                    }
                                  })
                                : null,
                            title: Text(
                              mod.name,
                              style: TextStyle(
                                decoration: mod.isAvailable
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: mod.description != null
                                ? Text(mod.description!)
                                : null,
                            secondary: Text(
                              mod.priceAdjustment >= 0
                                  ? '+${mod.priceAdjustment.toStringAsFixed(0)} ${l10n.currencySymbol}'
                                  : '-${mod.priceAdjustment.abs().toStringAsFixed(0)} ${l10n.currencySymbol}',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: mod.priceAdjustment >= 0
                                    ? context.colorScheme.primary
                                    : context.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 700),
                      child: Text(
                        l10n.quantity,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 550),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: _quantity > 1
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '$_quantity',
                                key: ValueKey(_quantity),
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _quantity++),
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: context.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 600),
                      child: TextField(
                        controller: _instructionsController,
                        decoration: InputDecoration(
                          hintText: l10n.specialInstructions,
                          hintStyle: TextStyle(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: product.isAvailable
                    ? () async {
                        final cartRepo = ref.read(cartRepositoryProvider);
                        await cartRepo.addToCart(
                          merchantId: widget.merchantId,
                          merchantName: widget.merchantName,
                          item: commerce.CartItem(
                            id: 'ci_${DateTime.now().millisecondsSinceEpoch}',
                            productId: product.id,
                            productName: product.name,
                            variantName: selectedVariant?.name,
                            quantity: _quantity,
                            unitPrice: unitPrice,
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${l10n.addToCart} - ${totalPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
                              ),
                              action: SnackBarAction(
                                label: l10n.cart,
                                onPressed: () => context.push('/market/cart'),
                              ),
                            ),
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  '${l10n.addToCart} - ${totalPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
